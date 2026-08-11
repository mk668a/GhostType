import Foundation

enum ModelDownloadError: LocalizedError {
    case httpError(Int)
    case truncated(expected: Int64, got: Int64)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return String(format: String(localized: "Download failed with HTTP %d. Check your connection and try again."), code)
        case .truncated(let expected, let got):
            let e = ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)
            let g = ByteCountFormatter.string(fromByteCount: got, countStyle: .file)
            return String(format: String(localized: "Download was incomplete (%1$@ of %2$@). Try again."), g, e)
        case .cancelled:
            return String(localized: "Download cancelled.")
        }
    }
}

/// The two values the URLSession delegate needs while running off the main
/// actor. They are written once before `resume()` and only read afterwards, so
/// a lock is enough — and it lets `didFinishDownloadingTo` move the temporary
/// file synchronously, which it must, because URLSession deletes that file the
/// moment the callback returns.
private final class TransferContext: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDestination: URL?
    private var storedExpectedBytes: Int64 = 0

    var destination: URL? { lock.withLock { storedDestination } }
    var expectedBytes: Int64 { lock.withLock { storedExpectedBytes } }

    func set(destination: URL, expectedBytes: Int64) {
        lock.withLock {
            storedDestination = destination
            storedExpectedBytes = expectedBytes
        }
    }
}

/// Downloads catalog models into Application Support with live progress.
///
/// Resumable by design: a multi-gigabyte GGUF over a laptop's connection will
/// get interrupted, and making the user start over is the fastest way to lose
/// them during first-run setup.
@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case downloading(received: Int64, total: Int64)
        case finished
        case failed(String)
    }

    static let shared = ModelDownloader()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activeModelID: String?

    var fractionCompleted: Double? {
        guard case .downloading(let received, let total) = phase, total > 0 else { return nil }
        return Double(received) / Double(total)
    }

    var isDownloading: Bool {
        if case .downloading = phase { return true }
        return false
    }

    private var task: URLSessionDownloadTask?
    private var resumeData: Data?
    private var continuation: CheckedContinuation<Void, Error>?
    private let context = TransferContext()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // The default 60s resource timeout would kill a multi-gigabyte transfer
        // outright. Bound the idle gap between packets instead of the whole
        // download.
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 24 * 60 * 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() { super.init() }

    func download(_ model: CatalogModel) async throws {
        guard !isDownloading else { return }

        try ModelStore.ensureDirectoryExists()
        context.set(destination: ModelStore.localURL(for: model), expectedBytes: model.sizeBytes)
        activeModelID = model.id
        phase = .downloading(received: 0, total: model.sizeBytes)

        let downloadTask: URLSessionDownloadTask
        if let resumeData {
            downloadTask = session.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else {
            downloadTask = session.downloadTask(with: model.downloadURL)
        }
        task = downloadTask

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.continuation = continuation
                downloadTask.resume()
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    /// Stops the transfer but keeps the bytes already on disk, so the next
    /// attempt resumes instead of starting a multi-gigabyte download over.
    func cancel() {
        guard let task else { return }
        self.task = nil
        task.cancel { [weak self] data in
            Task { @MainActor in
                self?.resumeData = data
                self?.finish(with: ModelDownloadError.cancelled)
            }
        }
    }

    func reset() {
        guard !isDownloading else { return }
        phase = .idle
        activeModelID = nil
    }

    fileprivate func finish(with error: Error?) {
        task = nil
        guard let continuation else { return }
        self.continuation = nil

        if let error {
            if case ModelDownloadError.cancelled = error {
                phase = .idle
            } else {
                phase = .failed(error.localizedDescription)
            }
            continuation.resume(throwing: error)
        } else {
            phase = .finished
            continuation.resume()
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Hugging Face redirects to a CDN that does send Content-Length, but
        // fall back to the catalog size if a proxy strips it so the progress
        // bar never sits at an indeterminate 0%.
        let fallback = context.expectedBytes
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : fallback
        Task { @MainActor in
            guard self.isDownloading else { return }
            self.phase = .downloading(received: totalBytesWritten, total: total)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            Task { @MainActor in self.finish(with: ModelDownloadError.httpError(statusCode)) }
            return
        }

        let expected = context.expectedBytes
        let attributes = try? FileManager.default.attributesOfItem(atPath: location.path)
        let got = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        // A CDN error page or a truncated transfer would otherwise be handed to
        // llama.cpp as a GGUF, which fails with a parse error the user has no
        // way to interpret.
        guard got >= Int64(Double(expected) * 0.98) else {
            Task { @MainActor in self.finish(with: ModelDownloadError.truncated(expected: expected, got: got)) }
            return
        }

        guard let destination = context.destination else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in self.finish(with: nil) }
        } catch {
            Task { @MainActor in self.finish(with: error) }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        // Cancellation lands here too, but `cancel()` already resolved the
        // continuation once the resume data came back.
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        Task { @MainActor in self.finish(with: error) }
    }
}
