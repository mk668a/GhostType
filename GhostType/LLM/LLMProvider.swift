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
    case inferenceError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning(let endpoint):
            return "LLM server is not running at \(endpoint). Start LM Studio, Ollama, or another OpenAI-compatible server."
        case .inferenceError(let msg):
            return "Inference error: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        }
    }
}

/// Connects to any OpenAI-compatible API server via the Chat Completions API.
/// Works with any model (chat, instruct, base) loaded in LM Studio, Ollama, etc.
final class LLMClient {
    private let endpoint: String
    private let model: String

    init(endpoint: String, model: String) {
        self.endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
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
        urlRequest.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .timedOut {
            throw LLMError.serverNotRunning(endpoint)
        } catch {
            throw LLMError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let respBody = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.inferenceError("Server returned \(httpResponse.statusCode): \(respBody)")
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
