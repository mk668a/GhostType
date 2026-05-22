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

    func complete(prefix: String, suffix: String, isManual: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        currentTask?.cancel()

        if !isManual, isSuppressed {
            completion(.failure(LLMError.suppressed))
            return
        }

        let client = getClient()

        let request = FIMRequest(
            prefix: prefix,
            suffix: suffix,
            maxTokens: settings.maxTokens,
            temperature: settings.temperature,
            topP: settings.topP,
            stopTokens: ["\n\n", "<|fim_pad|>", "<|endoftext|>"]
        )

        currentTask = Task {
            do {
                let result = try await client.complete(request: request)
                guard !Task.isCancelled else { return }
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                await self.recordSuccess()
                completion(.success(trimmed))
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

    /// User-driven reachability probe for Settings' "Test Connection". Updates
    /// `settings.connectionState` so the menu bar stays in sync with what the
    /// Settings panel just showed the user. Intentionally does not feed the
    /// breaker counter — a single explicit press should not push auto-trigger
    /// toward suppression — but a success does reset the breaker so a stale
    /// "Paused" state clears once the user proves the endpoint is healthy.
    @MainActor
    func probe() async -> Result<[String], Error> {
        let client = getClient()
        do {
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

    private func getClient() -> LLMClient {
        let endpoint = settings.serverEndpoint
        let model = settings.modelName

        if let existing = client, endpoint == lastEndpoint, model == lastModel {
            return existing
        }

        let newClient = LLMClient(endpoint: endpoint, model: model)
        client = newClient
        lastEndpoint = endpoint
        lastModel = model
        // New target: forget past failures so the breaker does not pre-suppress
        // requests against an endpoint we have not actually tried yet.
        resetBreaker()
        return newClient
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
