import Foundation

final class CompletionEngine {
    private let settings: AppSettings
    private var client: LLMClient?
    private var lastEndpoint: String = ""
    private var lastModel: String = ""
    private var currentTask: Task<Void, Never>?

    // Circuit breaker: after `failureThreshold` consecutive network failures,
    // auto-trigger requests short-circuit for `suppressDuration` seconds so a
    // broken endpoint does not keep firing slow requests on every keystroke.
    // Manual triggers always bypass the breaker.
    private static let failureThreshold = 3
    private static let suppressDuration: TimeInterval = 30
    private var consecutiveFailures: Int = 0
    private var suppressUntil: Date?

    /// True while the breaker is open. Read on the main actor.
    var isSuppressed: Bool {
        guard let until = suppressUntil else { return false }
        return until > Date()
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    func complete(
        prefix: String,
        suffix: String,
        isManual: Bool,
        bundleID: String? = nil,
        domain: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        currentTask?.cancel()

        if !isManual, isSuppressed {
            completion(.failure(LLMError.suppressed))
            return
        }

        currentTask = Task {
            do {
                let client = try await self.resolveClient()
                let request = await self.buildRequest(
                    prefix: prefix, suffix: suffix, bundleID: bundleID, domain: domain)
                let result = try await client.complete(request: request)
                guard !Task.isCancelled else { return }
                await self.recordSuccess()
                completion(.success(result))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await self.recordFailure(error)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    @MainActor
    private func buildRequest(prefix: String, suffix: String, bundleID: String?, domain: String?) -> FIMRequest {
        let extraContext = settings.learnWritingStyle
            ? WritingStyleStore.shared.context(bundleID: bundleID, domain: domain, excluding: prefix)
            : []

        let style = CompletionGrammar.style(
            preferred: settings.grammarStyle,
            fieldIsMultiline: prefix.contains("\n") || suffix.contains("\n")
        )
        return FIMRequest(
            prefix: prefix,
            suffix: suffix,
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            repeatPenalty: settings.repeatPenalty,
            extraContext: extraContext,
            // The FIM specials are listed explicitly because a base model that
            // has them will happily emit one mid-completion when it decides the
            // span is done, and llama.cpp only treats some of them as EOG.
            stopTokens: ["\n\n", "<|fim_pad|>", "<|endoftext|>", "<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>", "<|file_sep|>", "<|repo_name|>"],
            grammar: CompletionGrammar.gbnf(for: style)
        )
    }

    /// User-driven reachability probe for Settings' "Test Connection". Updates
    /// `settings.connectionState` so the menu bar stays in sync with what the
    /// Settings panel just showed the user. Intentionally does not feed the
    /// breaker counter — a single explicit press should not push auto-trigger
    /// toward suppression — but a success does reset the breaker so a stale
    /// "Paused" state clears once the user proves the endpoint is healthy.
    @MainActor
    func probe() async -> Result<[String], Error> {
        do {
            let client = try await resolveClient()
            let models = try await client.probe()
            consecutiveFailures = 0
            suppressUntil = nil
            settings.connectionState = .ok
            return .success(models)
        } catch {
            if let llmError = error as? LLMError, case .suppressed = llmError {
                // probe() never throws .suppressed today; guard defensively.
            } else {
                settings.connectionState = .unreachable
            }
            return .failure(error)
        }
    }

    // MARK: - Backend resolution

    /// Returns a client pointed at whichever backend the user selected,
    /// starting the bundled server first if that is the one in play.
    ///
    /// Both branches produce the same `LLMClient`, which is the point: the
    /// embedded backend is a process we supervise, not a second inference path
    /// to keep in sync with the external one.
    @MainActor
    private func resolveClient() async throws -> LLMClient {
        switch settings.backend {
        case .embedded:
            guard BundledLlamaServer.isAvailable else { throw EmbeddedServerError.binaryMissing }
            let model = CatalogModel.model(withID: settings.embeddedModelID) ?? CatalogModel.recommended
            let modelPath = ModelStore.localURL(for: model)
            guard ModelStore.isInstalled(model) else { throw EmbeddedServerError.modelMissing(modelPath) }

            let endpoint = try await BundledLlamaServer.shared.ensureRunning(
                modelPath: modelPath,
                contextSize: settings.contextWindow
            )
            return client(endpoint: endpoint, model: model.id, flavor: .llamaCpp)

        case .external:
            return client(endpoint: settings.serverEndpoint, model: settings.modelName, flavor: nil)
        }
    }

    @MainActor
    private func client(endpoint: String, model: String, flavor: ServerFlavor?) -> LLMClient {
        if let existing = client, endpoint == lastEndpoint, model == lastModel {
            return existing
        }

        let newClient = LLMClient(endpoint: endpoint, model: model, knownFlavor: flavor)
        client = newClient
        lastEndpoint = endpoint
        lastModel = model
        // New target: forget past failures so the breaker does not pre-suppress
        // requests against an endpoint we have not actually tried yet.
        resetBreaker()
        return newClient
    }

    /// Drops the cached client so the next completion rebuilds it. Called when
    /// the user switches backends or picks a different model, both of which
    /// change the endpoint out from under us.
    @MainActor
    func invalidateClient() {
        client = nil
        lastEndpoint = ""
        lastModel = ""
        resetBreaker()
    }

    private func resetBreaker() {
        consecutiveFailures = 0
        suppressUntil = nil
    }

    @MainActor
    private func recordSuccess() {
        consecutiveFailures = 0
        suppressUntil = nil
        settings.connectionState = .ok
    }

    @MainActor
    private func recordFailure(_ error: Error) {
        // A missing binary or an undownloaded model is a setup problem, not a
        // flaky endpoint. Surfacing it immediately (instead of after three
        // strikes) is what points the user at Settings.
        if error is EmbeddedServerError {
            settings.connectionState = .unreachable
            return
        }

        // Only network-class failures count toward the breaker. An inferenceError
        // means the server is alive but rejected the request (bad model name,
        // unsupported parameter, etc.) — suppressing auto-trigger would just hide
        // a misconfiguration the user needs to fix.
        guard let llmError = error as? LLMError else { return }
        switch llmError {
        case .serverNotRunning, .timedOut, .networkError:
            consecutiveFailures += 1
            if consecutiveFailures >= Self.failureThreshold {
                suppressUntil = Date().addingTimeInterval(Self.suppressDuration)
                settings.connectionState = .suppressed
            } else {
                settings.connectionState = .unreachable
            }
        case .inferenceError:
            settings.connectionState = .unreachable
        case .suppressed:
            break
        }
    }
}
