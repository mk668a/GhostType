import Foundation

/// A snippet of the user's own writing, kept to steer future completions.
struct WritingSample: Codable, Equatable {
    /// Bundle identifier of the app it was written in, when known.
    let bundleID: String?
    /// Web host, when it was written in a browser text field.
    let domain: String?
    let text: String
    let recordedAt: Date

    /// True when this sample and `other` are the same field session: one text
    /// is a prefix of the other because the user simply kept typing.
    func continues(_ other: WritingSample) -> Bool {
        guard bundleID == other.bundleID, domain == other.domain else { return false }
        return text.hasPrefix(other.text) || other.text.hasPrefix(text)
    }
}

/// Remembers how the user writes, locally, and feeds it back as context.
///
/// A base model completes whatever register the prompt is already in. Given
/// only the half-sentence at the cursor it has nothing to go on, so it defaults
/// to a generic one. Showing it a few things the same person recently wrote in
/// the same app is enough to pull the completion toward their phrasing, their
/// greeting, their sign-off, without any training step.
///
/// Everything stays in Application Support as plain JSON the user can read and
/// delete. Nothing is uploaded, and secure fields never reach this class: the
/// caller resolves `CompletionPolicy` first and drops the sample on the floor.
@MainActor
final class WritingStyleStore: ObservableObject {
    static let shared = WritingStyleStore()

    /// Enough to establish a voice without pushing the cursor-local text out of
    /// the context window, which is the signal that actually matters.
    static let samplesPerRequest = 3
    /// A sample shorter than this is a fragment and teaches the model nothing.
    private static let minimumSampleLength = 40
    /// Only the tail of a long field is kept; the recent sentences carry the
    /// voice and the opening paragraph mostly costs tokens.
    private static let maximumSampleLength = 400
    private static let maximumSamples = 120

    @Published private(set) var sampleCount: Int = 0

    private var samples: [WritingSample] = []
    private var saveTask: Task<Void, Never>?

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GhostType/writing-style.json")
    }

    private init() {
        load()
    }

    // MARK: - Recording

    /// Records what the user has written in the current field.
    ///
    /// Called with the text before the cursor, which is the user's own prose
    /// plus any completions they accepted, so it is exactly the voice we want
    /// to imitate.
    func record(text: String, bundleID: String?, domain: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumSampleLength else { return }

        let clipped = String(trimmed.suffix(Self.maximumSampleLength))
        let sample = WritingSample(bundleID: bundleID, domain: domain, text: clipped, recordedAt: Date())

        // Typing grows the prefix on every keystroke. Without this the store
        // would fill with 200 copies of the same paragraph at increasing
        // lengths, and every one of them would crowd out a different voice.
        if let index = samples.lastIndex(where: { $0.continues(sample) }) {
            samples[index] = sample
        } else {
            samples.append(sample)
        }

        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
        sampleCount = samples.count
        scheduleSave()
    }

    // MARK: - Retrieval

    /// Samples to send as extra context for a completion in this target.
    ///
    /// Same app or same site first, then most recent. The current text is
    /// excluded: handing the model the paragraph it is already completing does
    /// nothing except spend context.
    func context(bundleID: String?, domain: String?, excluding currentText: String) -> [String] {
        let current = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates = samples.filter { sample in
            guard !sample.text.isEmpty else { return false }
            return !current.hasSuffix(sample.text) && !sample.text.hasSuffix(current)
        }

        func matches(_ sample: WritingSample) -> Bool {
            if let domain, let sampleDomain = sample.domain { return domain == sampleDomain }
            if let bundleID, let sampleBundle = sample.bundleID { return bundleID == sampleBundle }
            return false
        }

        let sameTarget = candidates.filter(matches).suffix(Self.samplesPerRequest)
        if sameTarget.count >= Self.samplesPerRequest { return sameTarget.map(\.text) }

        // Fall back to recent writing from anywhere. Voice carries across apps
        // more than it varies within one, so a thin history is still useful.
        let remaining = Self.samplesPerRequest - sameTarget.count
        let others = candidates
            .filter { !matches($0) }
            .suffix(remaining)

        return (others + sameTarget).map(\.text)
    }

    // MARK: - Management

    func clear() {
        samples = []
        sampleCount = 0
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Drops everything recorded in one app, for when a user realises a
    /// particular app was capturing something they would rather forget.
    func clear(bundleID: String) {
        samples.removeAll { $0.bundleID == bundleID }
        sampleCount = samples.count
        scheduleSave()
    }

    // MARK: - Persistence

    /// Writes are coalesced: recording happens on a keystroke-driven path and
    /// rewriting the whole file each time would put disk I/O in the typing loop.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [samples] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            Self.write(samples, to: fileURL)
        }
    }

    private nonisolated static func write(_ samples: [WritingSample], to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(samples).write(to: url, options: .atomic)
        } catch {
            print("[GhostType] Could not save writing style: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        samples = (try? decoder.decode([WritingSample].self, from: data)) ?? []
        sampleCount = samples.count
    }
}
