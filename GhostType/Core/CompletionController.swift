import AppKit
import NaturalLanguage
import Combine
import Foundation

/// Glue between GlobalKeyMonitor (input), InputSourceMonitor (gating),
/// AccessibilityManager (context I/O), CompletionEngine (inference), and
/// OverlayWindowController (UI). All methods must be called on the main
/// thread; callers from background contexts hop via DispatchQueue.main.
final class CompletionController {
    private let settings: AppSettings
    private let engine: CompletionEngine
    private let overlay: OverlayWindowController
    private let keyMonitor: GlobalKeyMonitor
    private let inputSource: InputSourceMonitor

    private var textBuffer = ""
    private let maxBufferSize = 2048

    private var debounceTimer: Timer?

    private var pendingCompletion: String?
    private var isShowingCompletion = false {
        didSet { keyMonitor.setShowingCompletion(isShowingCompletion) }
    }

    private var cancellables = Set<AnyCancellable>()

    init(
        settings: AppSettings,
        engine: CompletionEngine,
        overlay: OverlayWindowController,
        keyMonitor: GlobalKeyMonitor,
        inputSource: InputSourceMonitor
    ) {
        self.settings = settings
        self.engine = engine
        self.overlay = overlay
        self.keyMonitor = keyMonitor
        self.inputSource = inputSource

        keyMonitor.onEvent = { [weak self] event in
            self?.handle(event)
        }

        keyMonitor.setEnabled(settings.isEnabled)
        keyMonitor.updateBindings(
            accept: settings.keyAccept,
            dismiss: settings.keyDismiss,
            manualTrigger: settings.keyManualTrigger,
            toggle: settings.keyToggle
        )

        observeSettings()
    }

    // MARK: - Settings sync

    private func observeSettings() {
        settings.$isEnabled
            .sink { [weak self] enabled in
                self?.keyMonitor.setEnabled(enabled)
                if !enabled { self?.dismiss() }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            settings.$keyAccept,
            settings.$keyDismiss,
            settings.$keyManualTrigger,
            settings.$keyToggle
        )
        .sink { [weak self] accept, dismiss, manual, toggle in
            self?.keyMonitor.updateBindings(
                accept: accept, dismiss: dismiss,
                manualTrigger: manual, toggle: toggle
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Event handling

    private func handle(_ event: KeyEvent) {
        switch event {
        case .toggle:
            settings.isEnabled.toggle()
        case .accept:
            accept(settings.tabAcceptsWord ? .word : .full)
        case .acceptAlternate:
            accept(settings.tabAcceptsWord ? .full : .word)
        case .dismiss:
            dismiss()
        case .manualTrigger:
            trigger(isManual: true)
        case .text(let str):
            appendToBuffer(str)
            if isShowingCompletion { dismiss() }
            scheduleAutoTrigger()
        case .deleteBackward:
            if !textBuffer.isEmpty { textBuffer.removeLast() }
            if isShowingCompletion { dismiss() }
        case .newline:
            textBuffer.append("\n")
            if isShowingCompletion { dismiss() }
        case .dismissingKey:
            if isShowingCompletion { dismiss() }
        }
    }

    private func appendToBuffer(_ str: String) {
        // Cheap front line, run on every keystroke: a bundle-identifier lookup
        // only. The full policy check walks the AX tree, which is too expensive
        // per keypress, so it runs at trigger time and wipes the buffer there.
        // This keeps a password manager's characters from ever landing in it.
        if let bundleID = AccessibilityManager.shared.focusedAppBundleID(),
           AppCompatibility.credentialAppBundleIDs.contains(bundleID) {
            textBuffer = ""
            return
        }

        textBuffer.append(str)
        if textBuffer.count > maxBufferSize {
            textBuffer = String(textBuffer.dropFirst(textBuffer.count - maxBufferSize))
        }
    }

    // MARK: - Trigger

    private func scheduleAutoTrigger() {
        debounceTimer?.invalidate()
        guard settings.autoTrigger else { return }

        // Suspend auto-trigger while a non-ASCII IME is composing.
        // The manual hotkey still works regardless.
        guard inputSource.isASCIICompatible else { return }

        let bundleID = AccessibilityManager.shared.focusedAppBundleID()
        if let bundleID = bundleID, settings.isManualOnly(bundleID) {
            return
        }
        if let bundleID = bundleID, settings.isExcluded(bundleID) {
            return
        }

        let interval = TimeInterval(settings.debounceMs) / 1000.0
        debounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.trigger(isManual: false)
        }
    }

    private func trigger(isManual: Bool) {
        guard settings.isEnabled else { return }

        let bundleID = AccessibilityManager.shared.focusedAppBundleID()
        if let bundleID = bundleID, settings.isExcluded(bundleID) { return }
        if !isManual, let bundleID = bundleID, settings.isManualOnly(bundleID) { return }

        // The non-negotiable floor, checked before anything reads the field.
        // A manual trigger does not override it: the point is that a password
        // never reaches the model or the keystroke buffer, not that it is
        // inconvenient to complete one.
        let domain = AccessibilityManager.shared.focusedWebDomain()
        let policy = AppCompatibility.policy(
            bundleID: bundleID,
            domain: domain,
            focusedFieldIsSecure: AccessibilityManager.shared.focusedFieldIsSecure()
        )
        if policy.secure { textBuffer = "" }
        if policy.completionsDisabled { return }
        if policy.manualOnly, !isManual { return }

        var context = resolveContext()
        guard context != nil else { return }
        if policy.midLineDisabled { context?.suffix = "" }
        guard let context else { return }
        guard !context.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let label = bundleID ?? "unknown"
        print("[GhostType] \(isManual ? "Manual" : "Auto") trigger in: \(label)")

        // Don't show "Thinking..." for a request the breaker will immediately
        // short-circuit — the status would flicker for one frame and then snap
        // back, which looks like the app is stuck.
        if !engine.isSuppressed || isManual {
            settings.statusText = String(localized: "Thinking...")
        }

        // Record what the user has written here before asking for more. The
        // policy check above already returned for secure fields and credential
        // apps, so nothing sensitive reaches the store.
        if settings.learnWritingStyle {
            let recorded = context.prefix
            Task { @MainActor in
                WritingStyleStore.shared.record(text: recorded, bundleID: bundleID, domain: domain)
            }
        }

        engine.complete(
            prefix: context.prefix,
            suffix: context.suffix,
            isManual: isManual,
            bundleID: bundleID,
            domain: domain
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let text):
                    var completion = Self.normalize(text, following: context.prefix)
                    completion = Self.capLength(completion, to: self.settings.maxCompletionChars)
                    guard !completion.isEmpty else {
                        self.settings.statusText = String(localized: "Ready")
                        return
                    }
                    self.show(completion, cursorRect: context.cursorRect)
                    self.settings.statusText = String(localized: "Ready")
                case .failure(let error):
                    // Suppressed = breaker open; stay silent so we don't pester
                    // the user with errors on every keystroke.
                    if case LLMError.suppressed = error { return }

                    print("[GhostType] Completion error: \(error.localizedDescription)")
                    // Keep the error text visible until the next success or
                    // user action. The previous 2-second auto-revert to "Ready"
                    // hid the problem and confused users (see Reddit feedback).
                    self.settings.statusText = error.localizedDescription
                }
            }
        }
    }

    /// Trims a completion without destroying the space that joins it to what
    /// the user already typed.
    ///
    /// A fill-in-the-middle model emits that space itself — the completion for
    /// "Hello" is " world" — so blanket-trimming the leading whitespace is what
    /// produced "Helloworld". The space is only dropped when the prefix already
    /// ends in one, which is the case that would otherwise double it up.
    private static func normalize(_ text: String, following prefix: String) -> String {
        var result = text
        while let last = result.last, last == " " || last == "\n" || last == "\t" {
            result.removeLast()
        }
        if let lastPrefixCharacter = prefix.last, lastPrefixCharacter.isWhitespace {
            while let first = result.first, first == " " || first == "\t" {
                result.removeFirst()
            }
        }
        return result
    }

    /// Trims an over-long suggestion back to the last word boundary that fits.
    ///
    /// The token budget bounds generation, but tokens are not characters and a
    /// model that spends all of them on one clause still produces more ghost
    /// text than anyone reads mid-sentence. Cutting at a word boundary keeps
    /// what is shown readable; cutting mid-word would look like a rendering bug.
    static func capLength(_ text: String, to limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }

        let capped = text.prefix(limit)
        guard let lastBreak = capped.lastIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) else {
            // A single word longer than the whole budget: show it whole rather
            // than a fragment the user cannot act on.
            return String(capped)
        }
        return String(capped[capped.startIndex..<lastBreak])
    }

    private func resolveContext() -> TextContext? {
        if let ax = AccessibilityManager.shared.getTextContext(maxChars: settings.contextWindow) {
            return ax
        }
        // Fallback: synthesize a context from the typed-key buffer.
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cursor = AccessibilityManager.shared.getCursorPosition()
        return TextContext(prefix: textBuffer, suffix: "", cursorRect: cursor)
    }

    // MARK: - Show / Accept / Dismiss

    private func show(_ text: String, cursorRect: CGRect) {
        pendingCompletion = text
        isShowingCompletion = true
        overlay.show(text: text, at: cursorRect)
    }

    enum AcceptGranularity {
        case word
        case full
    }

    /// Inserts part or all of the pending suggestion.
    ///
    /// Taking a word at a time is what makes a long suggestion safe to show:
    /// the user stops exactly where they stop agreeing instead of accepting a
    /// sentence and deleting half of it. The remainder stays on screen as ghost
    /// text, so repeated presses walk through it.
    private func accept(_ granularity: AcceptGranularity) {
        guard let text = pendingCompletion, !text.isEmpty else { return }

        let head: String
        let rest: String
        switch granularity {
        case .full:
            head = text
            rest = ""
        case .word:
            (head, rest) = Self.splitFirstWord(text)
        }

        guard !head.isEmpty else { return }

        // Insertion moves the caret, so the overlay has to be torn down and
        // re-shown at the new position rather than left where it was.
        dismiss()
        AccessibilityManager.shared.insertText(head)
        textBuffer = ""

        guard !rest.isEmpty else { return }
        let cursor = AccessibilityManager.shared.getCursorPosition()
        show(rest, cursorRect: cursor)
    }

    /// Splits off the leading whitespace plus the first word.
    ///
    /// The leading space belongs to the accepted part: taking "world" out of
    /// " world today" and leaving " " behind would glue the word to what the
    /// user already typed.
    ///
    /// Word boundaries come from `NLTokenizer` rather than from whitespace,
    /// because Japanese, Chinese, and Thai do not put spaces between words. A
    /// whitespace split in those scripts runs to the end of the line, which
    /// makes accepting a word identical to accepting everything and quietly
    /// removes the feature for anyone writing in them.
    static func splitFirstWord(_ text: String) -> (head: String, rest: String) {
        var start = text.startIndex
        while start < text.endIndex, text[start] == " " || text[start] == "\t" {
            start = text.index(after: start)
        }
        guard start < text.endIndex else { return (text, "") }

        let body = String(text[start...])
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = body

        let tokenRange = tokenizer.tokenRange(at: body.startIndex)
        guard !tokenRange.isEmpty else { return (text, "") }

        // NLTokenizer indexes into `body`, so the boundary has to be measured
        // as an offset and re-applied to the original string, which still
        // carries the leading whitespace.
        let offset = body.distance(from: body.startIndex, to: tokenRange.upperBound)
        let end = text.index(start, offsetBy: offset)
        return (String(text[text.startIndex..<end]), String(text[end...]))
    }

    private func dismiss() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        engine.cancel()
        overlay.hide()
        pendingCompletion = nil
        isShowingCompletion = false
    }
}
