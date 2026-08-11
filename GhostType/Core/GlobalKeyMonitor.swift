import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Key events surfaced from the global event tap to interested clients.
enum KeyEvent {
    /// A printable character was typed (after layout + modifiers applied).
    /// `payload` is the unicode string the system would have inserted.
    case text(String)
    /// Backspace was pressed. The tap forwards it untouched.
    case deleteBackward
    /// Return / Enter was pressed. The tap forwards it untouched.
    case newline
    /// A key that should dismiss any in-flight completion (arrows, page-up, etc.)
    case dismissingKey
    /// The accept-completion hotkey fired. The tap swallows the event.
    case accept
    /// The accept key with Shift held: takes the other granularity.
    case acceptAlternate
    /// The dismiss-completion hotkey fired. The tap swallows the event.
    case dismiss
    /// The manual-trigger hotkey fired. The tap swallows the event.
    case manualTrigger
    /// The global toggle hotkey fired. The tap swallows the event.
    case toggle
}

/// Snapshot of state the event-tap callback needs to read synchronously.
/// Mutated on the main thread, read on the tap thread under a lock.
private struct TapState {
    var isEnabled: Bool = true
    var isShowingCompletion: Bool = false
    var keyAccept: KeyBinding = .defaultAccept
    var keyDismiss: KeyBinding = .defaultDismiss
    var keyManualTrigger: KeyBinding = .defaultManualTrigger
    var keyToggle: KeyBinding = .defaultToggle
}

/// System-wide key event tap. Sees every keystroke after Accessibility
/// permission is granted, can swallow Tab/Esc/manual-trigger when needed,
/// and forwards typed text to a handler on the main queue.
final class GlobalKeyMonitor {

    /// Called on the main queue.
    var onEvent: ((KeyEvent) -> Void)?

    private(set) var isRunning: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let stateLock = NSLock()
    private var state = TapState()

    // MARK: - Lifecycle

    @discardableResult
    func start() -> Bool {
        stop()

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<GlobalKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: opaqueSelf
        ) else {
            print("[GhostType] CGEvent.tapCreate failed. Is Accessibility permission granted?")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    // MARK: - State Updates (main thread)

    func setEnabled(_ value: Bool) {
        stateLock.lock(); defer { stateLock.unlock() }
        state.isEnabled = value
    }

    func setShowingCompletion(_ value: Bool) {
        stateLock.lock(); defer { stateLock.unlock() }
        state.isShowingCompletion = value
    }

    func updateBindings(
        accept: KeyBinding,
        dismiss: KeyBinding,
        manualTrigger: KeyBinding,
        toggle: KeyBinding
    ) {
        stateLock.lock(); defer { stateLock.unlock() }
        state.keyAccept = accept
        state.keyDismiss = dismiss
        state.keyManualTrigger = manualTrigger
        state.keyToggle = toggle
    }

    // MARK: - Tap Callback

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if the OS disabled it (timeout or user input).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let snapshot: TapState = {
            stateLock.lock(); defer { stateLock.unlock() }
            return state
        }()

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Toggle works even when GhostType is disabled.
        if snapshot.keyToggle.matches(keyCode: keyCode, flags: flags) {
            emit(.toggle)
            return nil
        }

        guard snapshot.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        // Accept / Dismiss only fire when a completion is on screen.
        if snapshot.isShowingCompletion {
            if snapshot.keyAccept.matches(keyCode: keyCode, flags: flags) {
                emit(.accept)
                return nil
            }
            if snapshot.keyAccept.matchesWithShiftAdded(keyCode: keyCode, flags: flags) {
                emit(.acceptAlternate)
                return nil
            }
            if snapshot.keyDismiss.matches(keyCode: keyCode, flags: flags) {
                emit(.dismiss)
                return nil
            }
        }

        // Manual trigger.
        if snapshot.keyManualTrigger.matches(keyCode: keyCode, flags: flags) {
            emit(.manualTrigger)
            return nil
        }

        // Classify the keystroke for the completion controller. The event
        // itself is always forwarded so the focused app behaves normally.
        if let classified = classify(keyCode: keyCode, flags: flags, event: event) {
            emit(classified)
        }

        return Unmanaged.passUnretained(event)
    }

    private func classify(keyCode: Int64, flags: CGEventFlags, event: CGEvent) -> KeyEvent? {
        // Ignore key combos that contain Command/Control — these are app shortcuts,
        // not typing. Option-modified keys can still produce printable characters
        // (e.g. å on Option+A), so we allow them through.
        let blockingMods: CGEventFlags = [.maskCommand, .maskControl]
        if !flags.intersection(blockingMods).isEmpty {
            // Still dismiss the overlay on shortcuts though.
            return .dismissingKey
        }

        switch Int(keyCode) {
        case kVK_Delete, kVK_ForwardDelete:
            return .deleteBackward
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return .newline
        case kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
             kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
             kVK_Escape, kVK_Tab:
            return .dismissingKey
        default:
            break
        }

        // Extract the unicode string the keystroke would produce.
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }

        let str = String(utf16CodeUnits: buffer, count: length)
        guard !str.isEmpty else { return nil }

        // Skip control characters that slipped past the keycode switch.
        if let scalar = str.unicodeScalars.first, scalar.value < 0x20 {
            return nil
        }

        return .text(str)
    }

    private func emit(_ event: KeyEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
