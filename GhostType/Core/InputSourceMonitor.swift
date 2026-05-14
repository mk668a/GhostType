import Carbon
import Foundation

/// Tracks the current keyboard input source so the completion engine can
/// suspend auto-trigger while a non-ASCII IME (Japanese, Chinese, Korean, etc.)
/// is composing. We treat the source as "safe" only when it is a plain
/// keyboard layout AND advertises ASCII capability.
final class InputSourceMonitor {
    static let shared = InputSourceMonitor()

    private(set) var isASCIICompatible: Bool = true
    private(set) var currentSourceID: String = ""

    private var observer: CFNotificationCenter?

    private init() {
        refresh()
        startObserving()
    }

    deinit {
        stopObserving()
    }

    private func startObserving() {
        let center = CFNotificationCenterGetDistributedCenter()
        observer = center

        let opaque = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            opaque,
            { _, opaque, _, _, _ in
                guard let opaque = opaque else { return }
                let monitor = Unmanaged<InputSourceMonitor>.fromOpaque(opaque).takeUnretainedValue()
                DispatchQueue.main.async { monitor.refresh() }
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    private func stopObserving() {
        if let center = observer {
            let opaque = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterRemoveEveryObserver(center, opaque)
        }
        observer = nil
    }

    func refresh() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            isASCIICompatible = true
            currentSourceID = ""
            return
        }

        currentSourceID = stringProperty(source, key: kTISPropertyInputSourceID) ?? ""
        let typeID = stringProperty(source, key: kTISPropertyInputSourceType) ?? ""
        let isASCIICapable = boolProperty(source, key: kTISPropertyInputSourceIsASCIICapable)

        // Safe = a keyboard layout (not an IME input mode) that is ASCII-capable.
        // Japanese "Hiragana", Chinese "Pinyin", Korean "2-Set" etc. all use
        // type = TISTypeKeyboardInputMode and are filtered out here.
        let isLayout = (typeID == (kTISTypeKeyboardLayout as String))
        isASCIICompatible = isLayout && isASCIICapable
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }
}
