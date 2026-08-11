import AppKit
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
            accept()
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
                    let completion = Self.normalize(text, following: context.prefix)
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

    private func accept() {
        guard let text = pendingCompletion else { return }
        let textToInsert = text
        dismiss()
        AccessibilityManager.shared.insertText(textToInsert)
        textBuffer = ""
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
