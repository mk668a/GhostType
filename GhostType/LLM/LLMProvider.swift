import Foundation

struct FIMRequest {
    let prefix: String
    let suffix: String
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    /// Penalty applied to tokens already present in the recent window.
    ///
    /// llama.cpp defaults this to 1.0, meaning off, and a small base model with
    /// it off will happily emit "I'll get it done. I'll get it done. I'll get
    /// it done." until it hits the token budget. 1.1 removes the loop without
    /// pushing the model off-topic; presence and frequency penalties were tried
    /// here too and made completions worse, so they are deliberately not sent.
    let repeatPenalty: Double
    let stopTokens: [String]
    /// GBNF source, or nil to sample unconstrained. Only honoured by servers
    /// that speak llama.cpp's API.
    let grammar: String?
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

/// What the server on the other end can actually do.
///
/// This is the whole reason GhostType keeps a single HTTP client instead of
/// splitting embedded and external into separate inference paths: a user who
/// already runs `llama-server` gets exactly the same fill-in-the-middle and
/// grammar-constrained quality as the bundled backend, and everyone else still
/// works over plain chat completions.
enum ServerFlavor: Equatable {
    /// Native llama.cpp HTTP API: `/infill`, `/completion`, GBNF grammars.
    case llamaCpp
    /// Anything that only promises `/v1/chat/completions`.
    case openAICompatible
}

/// Talks to one inference server. Created per (endpoint, model) pair.
actor LLMClient {
    private let endpoint: String
    private let model: String
    /// Set for the bundled server, where we launched the process ourselves and
    /// do not need to spend a round trip discovering what it is.
    private let knownFlavor: ServerFlavor?

    private var resolvedFlavor: ServerFlavor?
    /// Flips to false once a server tells us the loaded model has no FIM
    /// tokens, so we stop paying for a failed `/infill` on every keystroke.
    private var infillSupported = true

    private let session: URLSession

    init(endpoint: String, model: String, knownFlavor: ServerFlavor? = nil) {
        self.endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
        self.knownFlavor = knownFlavor

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
        switch await flavor() {
        case .llamaCpp:
            return try await completeNatively(request)
        case .openAICompatible:
            return try await completeViaChat(request)
        }
    }

    // MARK: - Flavor detection

    private func flavor() async -> ServerFlavor {
        if let knownFlavor { return knownFlavor }
        if let resolvedFlavor { return resolvedFlavor }

        // `/props` is llama.cpp's own endpoint and reports its slot
        // configuration. LM Studio and Ollama answer 404 here, which is the
        // signal we want.
        var detected = ServerFlavor.openAICompatible
        if let url = URL(string: "\(endpoint)/props"),
           let (data, response) = try? await session.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["default_generation_settings"] != nil || json["total_slots"] != nil {
            detected = .llamaCpp
        }
        resolvedFlavor = detected
        return detected
    }

    // MARK: - llama.cpp native path

    /// Uses `/infill` when there is text after the cursor and the model has FIM
    /// tokens, and `/completion` otherwise.
    ///
    /// The distinction matters: a plain continuation prompt has no way to tell
    /// the model that "…and I'll see you|tomorrow." already has a tail, so it
    /// happily writes a second one. Fill-in-the-middle is the whole reason a
    /// completion lands mid-sentence instead of duplicating the suffix.
    private func completeNatively(_ request: FIMRequest) async throws -> String {
        let hasSuffix = !request.suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasSuffix, infillSupported {
            do {
                return try await postNative(path: "/infill", body: nativeBody(request, useInfill: true))
            } catch let error as LLMError {
                guard case .inferenceError(let message) = error, isMissingFIMSupport(message) else { throw error }
                // Fall through: this model has no FIM tokens, so treat it as a
                // continuation model from here on.
                infillSupported = false
            }
        }

        return try await postNative(path: "/completion", body: nativeBody(request, useInfill: false))
    }

    private func isMissingFIMSupport(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("infill") || lowered.contains("fim")
    }

    private func nativeBody(_ request: FIMRequest, useInfill: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "n_predict": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.topP,
            "repeat_penalty": request.repeatPenalty,
            "repeat_last_n": 256,
            "stop": request.stopTokens,
            "stream": false,
            // Consecutive keystrokes resend an almost identical prefix; reusing
            // the cached KV is what makes auto-trigger affordable.
            "cache_prompt": true,
        ]
        if let grammar = request.grammar, !grammar.isEmpty {
            body["grammar"] = grammar
        }
        if useInfill {
            body["input_prefix"] = request.prefix
            body["input_suffix"] = request.suffix
        } else {
            body["prompt"] = request.prefix
        }
        return body
    }

    private func postNative(path: String, body: [String: Any]) async throws -> String {
        let url = URL(string: "\(endpoint)\(path)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performRequest(urlRequest)

        guard httpResponse.statusCode == 200 else {
            throw LLMError.inferenceError(errorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            throw LLMError.inferenceError(String(localized: "Invalid response format from server"))
        }
        return cleanResponse(content)
    }

    // MARK: - OpenAI-compatible path

    /// Chat completions with a `[CURSOR]` marker. Lossy compared to real FIM —
    /// the model has to be *told* where the cursor is rather than shown — but
    /// it is the only thing every OpenAI-compatible server agrees on.
    private func completeViaChat(_ request: FIMRequest) async throws -> String {
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

        let (data, httpResponse) = try await performRequest(urlRequest)

        guard httpResponse.statusCode == 200 else {
            throw LLMError.inferenceError(errorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.inferenceError(String(localized: "Invalid response format from server"))
        }

        return cleanResponse(content)
    }

    // MARK: - Probing

    /// Lightweight reachability probe. Returns the model IDs the server reports,
    /// which is empty for a llama.cpp server that only has one model loaded.
    func probe() async throws -> [String] {
        let url = URL(string: "\(endpoint)/v1/models")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, httpResponse) = try await performRequest(urlRequest)

        guard httpResponse.statusCode == 200 else {
            throw LLMError.inferenceError(errorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { $0["id"] as? String }
    }

    /// Which API this client decided to speak. Exposed so Settings can tell the
    /// user whether their external server unlocked the FIM path.
    func detectedFlavor() async -> ServerFlavor {
        await flavor()
    }

    // MARK: - Shared plumbing

    /// Sends the request via the bounded-timeout session and maps URL errors
    /// into our domain `LLMError` cases so callers can branch on intent.
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
            throw LLMError.networkError(String(localized: "No HTTP response"))
        }
        return (data, httpResponse)
    }

    /// Prefers the server's own error text over a bare status code, because
    /// "Infill is not supported by this model" is actionable and "HTTP 400" is not.
    private func errorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        let trimmed = raw.count > 200 ? String(raw.prefix(200)) + "…" : raw
        return "HTTP \(statusCode): \(trimmed)"
    }

    private func cleanResponse(_ text: String) -> String {
        var cleaned = text

        // Remove markdown code fences if the model wrapped the output. The
        // grammar prevents this on the native path, but a plain OpenAI-compatible
        // server has no grammar to hold it back.
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            cleaned = cleaned
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^```[a-zA-Z]*\\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\n?```$", with: "", options: .regularExpression)
        }

        // Remove surrounding quotes if the model quoted the output
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count > 1) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count > 1) {
            cleaned = String(trimmed.dropFirst().dropLast())
        }

        // Leading whitespace is meaningful for an inline completion — " world"
        // after "Hello" is correct and "world" is not — so only the trailing
        // side is trimmed here.
        while cleaned.hasSuffix("\n") || cleaned.hasSuffix(" ") {
            cleaned.removeLast()
        }
        return cleaned
    }
}
