import Foundation

struct FIMRequest {
    let prefix: String
    let suffix: String
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let stopTokens: [String]
}

enum LLMError: LocalizedError {
    case serverNotRunning(String)
    case timedOut(String)
    case inferenceError(String)
    case networkError(String)
    /// Auto-trigger short-circuited by the local circuit breaker after repeated failures.
    /// Surfaced as a non-error: the controller stays silent so the user is not pestered.
    case suppressed

    var errorDescription: String? {
        switch self {
        case .serverNotRunning(let endpoint):
            return String(
                format: String(localized: "LLM server is not running at %@. Start LM Studio, Ollama, or another OpenAI-compatible server."),
                endpoint
            )
        case .timedOut(let endpoint):
            return String(
                format: String(localized: "Server at %@ is not responding (model may be loading or the endpoint URL may be wrong)."),
                endpoint
            )
        case .inferenceError(let msg):
            return String(format: String(localized: "Inference error: %@"), msg)
        case .networkError(let msg):
            return String(format: String(localized: "Network error: %@"), msg)
        case .suppressed:
            return String(localized: "Auto-trigger paused after repeated failures. Use the manual shortcut to retry.")
        }
    }
}

/// Connects to any OpenAI-compatible API server via the Chat Completions API.
/// Works with any model (chat, instruct, base) loaded in LM Studio, Ollama, etc.
final class LLMClient {
    private let endpoint: String
    private let model: String
    private let session: URLSession

    init(endpoint: String, model: String) {
        self.endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model

        // Dedicated session so timeouts are bounded by the session configuration
        // (URLSession.shared has a 60s default request timeout and a 7-day resource
        // timeout, which made stuck endpoints feel like a UI freeze).
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["Content-Type": "application/json"]
        self.session = URLSession(configuration: config)
    }

    func complete(request: FIMRequest) async throws -> String {
        // Use chat completions API — works with all models
        let url = URL(string: "\(endpoint)/v1/chat/completions")!

        let systemPrompt = """
        You are an inline text completion engine. The user will provide text with a cursor position marked as [CURSOR]. \
        Output ONLY the text that should be inserted at the cursor position. \
        Do not repeat the existing text. Do not add explanations, quotes, or formatting. \
        Output the completion text only, nothing else.
        """

        let userPrompt: String
        if request.suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userPrompt = "\(request.prefix)[CURSOR]"
        } else {
            userPrompt = "\(request.prefix)[CURSOR]\(request.suffix)"
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        var body: [String: Any] = [
            "messages": messages,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.topP,
            "stop": request.stopTokens,
            "stream": false
        ]
        if !model.isEmpty {
            body["model"] = model
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
                throw LLMError.serverNotRunning(endpoint)
            case .timedOut:
                throw LLMError.timedOut(endpoint)
            default:
                throw LLMError.networkError(error.localizedDescription)
            }
        } catch {
            throw LLMError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let trimmedBody = raw.count > 200 ? String(raw.prefix(200)) + "…" : raw
            throw LLMError.inferenceError("HTTP \(httpResponse.statusCode): \(trimmedBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.inferenceError("Invalid response format from server")
        }

        return cleanResponse(content)
    }

    private func cleanResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fences if the model wrapped the output
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "^```[a-zA-Z]*\\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\n?```$", with: "", options: .regularExpression)
        }

        // Remove surrounding quotes if the model quoted the output
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        return cleaned
    }
}
