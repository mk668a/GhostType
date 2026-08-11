import Foundation

enum EmbeddedServerError: LocalizedError {
    case binaryMissing
    case modelMissing(URL)
    case launchFailed(String)
    case notReady(String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return String(localized: "The bundled llama.cpp server is missing from this build. Reinstall GhostType, or switch to an external server in Settings.")
        case .modelMissing(let url):
            return String(format: String(localized: "Model file not found at %@. Download it again from Settings."), url.path)
        case .launchFailed(let msg):
            return String(format: String(localized: "Could not start the bundled server: %@"), msg)
        case .notReady(let msg):
            return String(format: String(localized: "The bundled server did not become ready: %@"), msg)
        }
    }
}

/// Supervises the `llama-server` binary shipped inside the app bundle.
///
/// The embedded backend is deliberately *not* a second inference path. It
/// starts llama.cpp on a loopback port and hands the resulting base URL to the
/// same `LLMClient` that talks to LM Studio / Ollama / vLLM, so there is one
/// completion code path for both zero-setup users and users who already run a
/// server. The only thing that changes between the two modes is which URL we
/// point at — and whether we are responsible for the process lifetime.
@MainActor
final class BundledLlamaServer: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running(endpoint: String)
        case failed(String)
    }

    static let shared = BundledLlamaServer()

    @Published private(set) var state: State = .stopped

    /// Endpoint of the running server, or nil when it is not up.
    var endpoint: String? {
        if case .running(let e) = state { return e }
        return nil
    }

    /// True when this build actually ships the llama.cpp binaries. A source
    /// build that skipped `scripts/fetch-llama.sh` will not have them, and the
    /// Settings UI needs to say so instead of failing at completion time.
    static var isAvailable: Bool { binaryURL != nil }

    /// `Contents/MacOS/llama-server`, the standard location for a helper
    /// executable. Its dylibs live in `Contents/Frameworks`, which the build
    /// phase points it at by rewriting its rpath.
    static var binaryURL: URL? {
        guard let url = Bundle.main.url(forAuxiliaryExecutable: "llama-server"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    private var process: Process?
    private var launchedModel: URL?
    private var launchedContextSize: Int = 0
    /// Serializes concurrent `ensureRunning` calls so a burst of keystrokes
    /// during startup cannot spawn several servers on different ports.
    private var startupTask: Task<String, Error>?

    /// Tail of the server's stderr, kept so a launch failure can be explained
    /// with llama.cpp's own words rather than a bare exit code.
    private var stderrTail: [String] = []
    private static let stderrTailLimit = 40

    private init() {}

    /// Brings the server up for `modelPath` and returns its base URL.
    ///
    /// Re-entrant and idempotent: if the server is already serving the same
    /// model with the same context size, the existing endpoint is returned
    /// untouched. Changing either restarts the process, because llama.cpp
    /// binds both at load time.
    func ensureRunning(modelPath: URL, contextSize: Int) async throws -> String {
        if case .running(let endpoint) = state,
           launchedModel == modelPath,
           launchedContextSize == contextSize,
           process?.isRunning == true {
            return endpoint
        }

        if let existing = startupTask,
           launchedModel == modelPath,
           launchedContextSize == contextSize {
            return try await existing.value
        }

        stop()

        launchedModel = modelPath
        launchedContextSize = contextSize
        state = .starting

        let task = Task { try await launch(modelPath: modelPath, contextSize: contextSize) }
        startupTask = task
        defer { startupTask = nil }

        do {
            let endpoint = try await task.value
            state = .running(endpoint: endpoint)
            return endpoint
        } catch {
            state = .failed(error.localizedDescription)
            stop()
            throw error
        }
    }

    func stop() {
        startupTask?.cancel()
        startupTask = nil
        if let process, process.isRunning {
            process.terminate()
            // llama.cpp unmaps a multi-GB model on SIGTERM; give it a beat
            // before the app tears the process group down under it.
            process.waitUntilExit()
        }
        process = nil
        if case .failed = state {} else { state = .stopped }
    }

    // MARK: - Launch

    private func launch(modelPath: URL, contextSize: Int) async throws -> String {
        guard let binary = Self.binaryURL else { throw EmbeddedServerError.binaryMissing }
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw EmbeddedServerError.modelMissing(modelPath)
        }

        let port = try Self.reserveEphemeralPort()
        let endpoint = "http://127.0.0.1:\(port)"

        let process = Process()
        process.executableURL = binary
        process.arguments = [
            "--model", modelPath.path,
            "--host", "127.0.0.1",
            "--port", String(port),
            "--ctx-size", String(max(512, contextSize * 4)),
            // Offload everything to Metal. On Apple Silicon this is the whole
            // point of running locally; on a model too big for the GPU, llama
            // .cpp falls back per-layer on its own.
            "--n-gpu-layers", "999",
            // Completions are short and latency-bound, so a small batch beats
            // a throughput-tuned default.
            "--batch-size", "512",
            "--ubatch-size", "512",
            // Consecutive keystrokes re-send an almost identical prefix.
            // Reusing the cached prefix is what keeps auto-trigger cheap.
            "--cache-reuse", "256",
            "--flash-attn", "auto",
            "--no-webui",
            "--alias", "ghosttype",
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()
        stderrTail = []
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty, let text = String(data: chunk, encoding: .utf8) else { return }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            Task { @MainActor in self?.appendStderr(lines) }
        }

        do {
            try process.run()
        } catch {
            throw EmbeddedServerError.launchFailed(error.localizedDescription)
        }
        self.process = process

        try await waitUntilHealthy(endpoint: endpoint, process: process)
        return endpoint
    }

    private func appendStderr(_ lines: [String]) {
        stderrTail.append(contentsOf: lines)
        if stderrTail.count > Self.stderrTailLimit {
            stderrTail.removeFirst(stderrTail.count - Self.stderrTailLimit)
        }
    }

    /// Polls `/health` until llama.cpp reports the model is loaded.
    ///
    /// The budget is generous because the first load of a multi-GB GGUF has to
    /// come off disk cold; subsequent launches hit the page cache and settle in
    /// a second or two.
    private func waitUntilHealthy(endpoint: String, process: Process) async throws {
        let deadline = Date().addingTimeInterval(180)
        let url = URL(string: "\(endpoint)/health")!
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: config)

        while Date() < deadline {
            if Task.isCancelled { throw CancellationError() }
            guard process.isRunning else {
                throw EmbeddedServerError.launchFailed(failureReason(exitCode: process.terminationStatus))
            }
            if let (_, response) = try? await session.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        throw EmbeddedServerError.notReady(failureReason(exitCode: nil))
    }

    private func failureReason(exitCode: Int32?) -> String {
        // Prefer llama.cpp's own last words — "unknown model architecture",
        // "failed to load model", etc. — over an exit code the user cannot act on.
        let meaningful = stderrTail.last { line in
            let lowered = line.lowercased()
            return lowered.contains("error") || lowered.contains("failed") || lowered.contains("unable")
        }
        if let meaningful { return meaningful }
        if let exitCode { return String(format: String(localized: "server exited with code %d"), exitCode) }
        return String(localized: "timed out while loading the model")
    }

    // MARK: - Port selection

    /// Asks the kernel for a free loopback port by binding to port 0 and
    /// reading back what it assigned. There is a small race between closing
    /// this socket and llama.cpp binding it, which is why a failed launch
    /// reports the server's stderr rather than assuming the port is fine.
    private static func reserveEphemeralPort() throws -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw EmbeddedServerError.launchFailed(String(localized: "could not open a socket to pick a port"))
        }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw EmbeddedServerError.launchFailed(String(localized: "could not reserve a loopback port"))
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard nameResult == 0 else {
            throw EmbeddedServerError.launchFailed(String(localized: "could not read back the reserved port"))
        }
        return UInt16(bigEndian: assigned.sin_port)
    }
}
