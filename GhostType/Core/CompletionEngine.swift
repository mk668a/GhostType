import Foundation

final class CompletionEngine {
    private let settings: AppSettings
    private var client: LLMClient?
    private var lastEndpoint: String = ""
    private var lastModel: String = ""
    private var currentTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func complete(prefix: String, suffix: String, completion: @escaping (Result<String, Error>) -> Void) {
        currentTask?.cancel()

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
                completion(.success(trimmed))
            } catch {
                guard !Task.isCancelled else { return }
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
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
        return newClient
    }
}
