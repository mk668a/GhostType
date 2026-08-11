import SwiftUI

@main
struct GhostTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No SwiftUI scenes: the settings window is managed by AppDelegate
        // because SwiftUI's Settings scene cannot be opened programmatically
        // from AppKit on macOS 14+ (requires SettingsLink, which is SwiftUI-only).
        // Without any Scene the @main App still works; AppDelegate handles the UI.
        Settings { EmptyView() }
    }
}

enum SettingsTab: String, Hashable {
    case setup, general, model, inference, appearance, excluded
}

// MARK: - Backend

/// Where inference runs.
///
/// Both options end at the same OpenAI-compatible HTTP surface. `.embedded`
/// means GhostType owns the process; `.external` means the user does. Keeping
/// them as two sources for one endpoint — rather than two engines — is what
/// lets someone who already runs LM Studio skip a second copy of the weights.
enum LLMBackend: String, CaseIterable, Identifiable {
    case embedded
    case external

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .embedded: return String(localized: "Built-in (llama.cpp)")
        case .external: return String(localized: "External server")
        }
    }

    var summary: String {
        switch self {
        case .embedded:
            return String(localized: "Download a model and GhostType runs it for you. Nothing else to install.")
        case .external:
            return String(localized: "Use a server you already run: LM Studio, Ollama, llama.cpp, vLLM. No second copy of the weights.")
        }
    }
}

// MARK: - Supported UI Languages
//
// To add a new language: add a `case` here with its locale code,
// then add translations for that locale in Localizable.xcstrings
// (open the catalog in Xcode and click "+" in the language column).
// `knownRegions` in project.pbxproj is auto-managed by Xcode.

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    /// Display name shown in the picker. Native (endonym) form so the user
    /// can recognize their language even if the UI is currently in another.
    var displayName: String {
        switch self {
        case .system:   return String(localized: "System Default")
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }
}

// MARK: - Connection State
//
// Reflects the most recent outcome of a completion request, so the menu bar
// can show whether the LLM endpoint is healthy at a glance.

enum ConnectionState: Equatable {
    case unknown        // No request attempted since launch
    case ok             // Last request succeeded
    case suppressed     // Auto-trigger temporarily paused after repeated failures
    case unreachable    // Last request failed (TCP error, timeout, or HTTP error)
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Backend Selection
    @Published var backend: LLMBackend = .embedded {
        didSet { save() }
    }
    /// Which catalog model the embedded backend loads.
    @Published var embeddedModelID: String = CatalogModel.recommended.id {
        didSet { save() }
    }

    // LLM Server Settings (external backend)
    @Published var serverEndpoint: String = "http://127.0.0.1:1234" {
        didSet { save() }
    }
    @Published var modelName: String = "" {
        didSet { save() }
    }

    /// How tightly the sampler is constrained. Only takes effect on servers
    /// that speak llama.cpp's API, which is every embedded run and any external
    /// `llama-server`.
    @Published var grammarStyle: CompletionGrammar.Style = .singleLine {
        didSet { save() }
    }

    /// What the accept key takes: one word, or the whole suggestion.
    ///
    /// Defaulting to a word is what makes a long suggestion harmless. The model
    /// can propose a whole sentence and the user still stops exactly where they
    /// stop agreeing, instead of accepting text they then have to delete.
    /// Shift plus the same key always does the other one.
    @Published var tabAcceptsWord: Bool = true {
        didSet { save() }
    }

    // Inference Parameters
    /// 64 produced suggestions longer than anyone reads mid-sentence. Inline
    /// completion is a clause, not a paragraph.
    @Published var maxTokens: Int = 24 {
        didSet { save() }
    }
    /// Hard ceiling on the suggestion actually shown, in characters. Trimmed
    /// back to a word boundary rather than cut mid-word.
    @Published var maxCompletionChars: Int = 120 {
        didSet { save() }
    }
    @Published var temperature: Double = 0.2 {
        didSet { save() }
    }
    @Published var topP: Double = 0.9 {
        didSet { save() }
    }
    @Published var repeatPenalty: Double = 1.1 {
        didSet { save() }
    }
    /// How much text around the cursor is sent, in characters.
    ///
    /// 512 was too small to be useful: three sentences into an email the model
    /// no longer sees how the message started, so it completes from a fragment.
    /// llama.cpp reuses the cached prefix between keystrokes, so a larger window
    /// costs far less than its size suggests.
    @Published var contextWindow: Int = 2048 {
        didSet { save() }
    }

    // Trigger Settings
    @Published var debounceMs: Int = 300 {
        didSet { save() }
    }
    @Published var autoTrigger: Bool = true {
        didSet { save() }
    }

    /// Keep a local record of how the user writes and feed it back as context.
    ///
    /// On by default: without it a base model has only the half-sentence at the
    /// cursor to go on and answers in a generic register, which is the single
    /// most common reason a completion gets dismissed. Everything stays on disk
    /// in Application Support and can be erased from Settings.
    @Published var learnWritingStyle: Bool = true {
        didSet { save() }
    }

    // UI Settings
    @Published var ghostTextOpacity: Double = 0.5 {
        didSet { save() }
    }
    @Published var fontSize: Double = 13.0 {
        didSet { save() }
    }

    // UI Language (empty string = follow system)
    @Published var preferredLanguage: String = "" {
        didSet {
            save()
            applyLanguagePreference()
        }
    }

    // Excluded Apps (auto-trigger disabled completely)
    @Published var excludedBundleIDs: [String] = [] {
        didSet { save() }
    }

    // Manual-trigger-only Apps (auto-trigger disabled, manual shortcut works)
    @Published var manualOnlyBundleIDs: [String] = [] {
        didSet { save() }
    }

    // Default excluded: IDEs and terminals (they have their own completions)
    static let defaultExcludedBundleIDs: [String] = [
        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        // IDEs
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "org.vim.MacVim",
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.WebStorm",
        "com.jetbrains.pycharm",
        "com.jetbrains.pycharm.ce",
        "com.jetbrains.CLion",
        "com.jetbrains.goland",
        "com.jetbrains.rider",
        "com.jetbrains.rubymine",
        "com.jetbrains.PhpStorm",
        "com.jetbrains.AppCode",
        "com.jetbrains.fleet",
        "dev.zed.Zed",
        "com.apple.dt.Xcode",
        "com.panic.Nova",
        "abnerworks.Typora",
    ]

    // Default manual-only: apps where auto-trigger may interfere
    static let defaultManualOnlyBundleIDs: [String] = [
        "com.apple.mail",
        "com.microsoft.Outlook",
        "com.tinyspeck.slackmacgap",       // Slack
        "com.hnc.Discord",                  // Discord
        "ru.keepcoder.Telegram",            // Telegram
        "com.facebook.archon.developerID",  // Messenger
    ]

    /// Check if a bundle ID is excluded (supports prefix matching for JetBrains etc.)
    func isExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    /// Check if a bundle ID is manual-trigger-only
    func isManualOnly(_ bundleID: String) -> Bool {
        manualOnlyBundleIDs.contains(bundleID)
    }

    // Key Bindings (stored as keyCode + modifierFlags)
    @Published var keyAccept: KeyBinding = .defaultAccept {
        didSet { save() }
    }
    @Published var keyDismiss: KeyBinding = .defaultDismiss {
        didSet { save() }
    }
    @Published var keyManualTrigger: KeyBinding = .defaultManualTrigger {
        didSet { save() }
    }
    @Published var keyToggle: KeyBinding = .defaultToggle {
        didSet { save() }
    }

    func resetKeyBindingsToDefaults() {
        keyAccept = .defaultAccept
        keyDismiss = .defaultDismiss
        keyManualTrigger = .defaultManualTrigger
        keyToggle = .defaultToggle
    }

    // State
    @Published var isEnabled: Bool = true {
        didSet { save() }
    }
    @Published var statusText: String = String(localized: "Ready")
    @Published var connectionState: ConnectionState = .unknown

    /// Drives which tab the Settings window opens to. Used by the menu bar's
    /// "Setup Guide..." action and by first-launch.
    @Published var settingsTab: SettingsTab = .general

    // First launch
    var isFirstLaunch: Bool {
        !defaults.bool(forKey: "hasLaunchedBefore")
    }

    func markLaunched() {
        defaults.set(true, forKey: "hasLaunchedBefore")
    }

    private let defaults = UserDefaults.standard

    init() {
        load()
        applyLanguagePreference()
    }

    /// Writes the chosen UI language to `AppleLanguages` so the next launch
    /// boots in that locale. macOS reads `AppleLanguages` early in process
    /// startup, so a relaunch is required to take effect on the running UI.
    private func applyLanguagePreference() {
        if preferredLanguage.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([preferredLanguage], forKey: "AppleLanguages")
        }
    }

    private func load() {
        // Existing installs were configured against an external server before
        // the embedded backend existed. Flipping them to `.embedded` on upgrade
        // would silently break a working setup and demand a multi-gigabyte
        // download, so only fresh installs get the zero-setup default.
        let hasLaunchedBefore = defaults.bool(forKey: "hasLaunchedBefore")
        let defaultBackend: LLMBackend = hasLaunchedBefore ? .external : .embedded
        backend = defaults.string(forKey: "backend").flatMap(LLMBackend.init(rawValue:)) ?? defaultBackend
        embeddedModelID = defaults.string(forKey: "embeddedModelID") ?? CatalogModel.recommended.id
        grammarStyle = defaults.string(forKey: "grammarStyle").flatMap(CompletionGrammar.Style.init(rawValue:)) ?? .singleLine
        serverEndpoint = defaults.string(forKey: "serverEndpoint") ?? "http://127.0.0.1:1234"
        modelName = defaults.string(forKey: "modelName") ?? ""
        // 64 was the old default and is longer than an inline suggestion
        // should be, so existing installs are lifted off it once.
        let storedMaxTokens = defaults.integer(forKey: "maxTokens").nonZero ?? 24
        maxTokens = storedMaxTokens == 64 ? 24 : storedMaxTokens
        maxCompletionChars = defaults.integer(forKey: "maxCompletionChars").nonZero ?? 120
        tabAcceptsWord = defaults.object(forKey: "tabAcceptsWord") as? Bool ?? true
        temperature = defaults.double(forKey: "temperature").nonZeroDouble ?? 0.2
        topP = defaults.double(forKey: "topP").nonZeroDouble ?? 0.9
        repeatPenalty = defaults.double(forKey: "repeatPenalty").nonZeroDouble ?? 1.1
        // Existing installs carry the old 512 default, which is small enough to
        // be the reason their completions felt off. Lift it once; a user who
        // deliberately picks another value keeps it.
        let storedContext = defaults.integer(forKey: "contextWindow").nonZero ?? 2048
        contextWindow = storedContext == 512 ? 2048 : storedContext
        debounceMs = defaults.integer(forKey: "debounceMs").nonZero ?? 300
        autoTrigger = defaults.object(forKey: "autoTrigger") as? Bool ?? true
        learnWritingStyle = defaults.object(forKey: "learnWritingStyle") as? Bool ?? true
        ghostTextOpacity = defaults.double(forKey: "ghostTextOpacity").nonZeroDouble ?? 0.5
        fontSize = defaults.double(forKey: "fontSize").nonZeroDouble ?? 13.0
        preferredLanguage = defaults.string(forKey: "preferredLanguage") ?? ""
        if let saved = defaults.stringArray(forKey: "excludedBundleIDs") {
            excludedBundleIDs = saved
        } else {
            excludedBundleIDs = AppSettings.defaultExcludedBundleIDs
        }
        if let saved = defaults.stringArray(forKey: "manualOnlyBundleIDs") {
            manualOnlyBundleIDs = saved
        } else {
            manualOnlyBundleIDs = AppSettings.defaultManualOnlyBundleIDs
        }
        isEnabled = defaults.object(forKey: "isEnabled") as? Bool ?? true
        if let d = defaults.data(forKey: "keyAccept"),    let k = try? JSONDecoder().decode(KeyBinding.self, from: d) { keyAccept = k }
        if let d = defaults.data(forKey: "keyDismiss"),   let k = try? JSONDecoder().decode(KeyBinding.self, from: d) { keyDismiss = k }
        if let d = defaults.data(forKey: "keyManualTrigger"), let k = try? JSONDecoder().decode(KeyBinding.self, from: d) {
            // Migrate the legacy Opt+\ default (which could leak a backslash on
            // some keyboards) to the safer Cmd+Opt+\ default.
            let legacy = KeyBinding(keyCode: 42, modifiers: [.option])
            keyManualTrigger = (k == legacy) ? .defaultManualTrigger : k
        }
        if let d = defaults.data(forKey: "keyToggle"),    let k = try? JSONDecoder().decode(KeyBinding.self, from: d) { keyToggle = k }
    }

    private func save() {
        defaults.set(backend.rawValue, forKey: "backend")
        defaults.set(embeddedModelID, forKey: "embeddedModelID")
        defaults.set(grammarStyle.rawValue, forKey: "grammarStyle")
        defaults.set(serverEndpoint, forKey: "serverEndpoint")
        defaults.set(modelName, forKey: "modelName")
        defaults.set(maxTokens, forKey: "maxTokens")
        defaults.set(maxCompletionChars, forKey: "maxCompletionChars")
        defaults.set(tabAcceptsWord, forKey: "tabAcceptsWord")
        defaults.set(temperature, forKey: "temperature")
        defaults.set(topP, forKey: "topP")
        defaults.set(repeatPenalty, forKey: "repeatPenalty")
        defaults.set(contextWindow, forKey: "contextWindow")
        defaults.set(debounceMs, forKey: "debounceMs")
        defaults.set(autoTrigger, forKey: "autoTrigger")
        defaults.set(learnWritingStyle, forKey: "learnWritingStyle")
        defaults.set(ghostTextOpacity, forKey: "ghostTextOpacity")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(preferredLanguage, forKey: "preferredLanguage")
        defaults.set(excludedBundleIDs, forKey: "excludedBundleIDs")
        defaults.set(manualOnlyBundleIDs, forKey: "manualOnlyBundleIDs")
        defaults.set(isEnabled, forKey: "isEnabled")
        if let d = try? JSONEncoder().encode(keyAccept) { defaults.set(d, forKey: "keyAccept") }
        if let d = try? JSONEncoder().encode(keyDismiss) { defaults.set(d, forKey: "keyDismiss") }
        if let d = try? JSONEncoder().encode(keyManualTrigger) { defaults.set(d, forKey: "keyManualTrigger") }
        if let d = try? JSONEncoder().encode(keyToggle) { defaults.set(d, forKey: "keyToggle") }
    }
}

// MARK: - Key Binding Model

struct KeyBinding: Equatable, Codable {
    var keyCode: Int     // CGKeyCode as Int
    var modifiers: Set<ModifierKey>

    enum ModifierKey: String, Codable, CaseIterable {
        case command, option, shift, control
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard Int(keyCode) == self.keyCode else { return false }
        // Normalize: only compare the 4 modifier keys we care about.
        // CGEventFlags contains many other bits (CapsLock, Fn, NumPad,
        // non-coalesced, etc.) that must be ignored.
        let relevantMask: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]
        let pressedMods = flags.intersection(relevantMask)

        var requiredMods: CGEventFlags = []
        for mod in modifiers {
            switch mod {
            case .command:  requiredMods.insert(.maskCommand)
            case .option:   requiredMods.insert(.maskAlternate)
            case .shift:    requiredMods.insert(.maskShift)
            case .control:  requiredMods.insert(.maskControl)
            }
        }
        return pressedMods == requiredMods
    }

    /// Matches this binding with Shift held on top of it.
    ///
    /// Used to give one key two granularities (Tab takes a word, Shift+Tab
    /// takes the whole suggestion) without asking the user to configure a
    /// second shortcut. Returns false when the binding already uses Shift,
    /// since then the two would be the same chord.
    func matchesWithShiftAdded(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard !modifiers.contains(.shift) else { return false }
        var shifted = self
        shifted.modifiers.insert(.shift)
        return shifted.matches(keyCode: keyCode, flags: flags)
    }

    static let defaultAccept = KeyBinding(keyCode: 48, modifiers: [])              // Tab
    static let defaultDismiss = KeyBinding(keyCode: 53, modifiers: [])             // Esc
    static let defaultManualTrigger = KeyBinding(keyCode: 42, modifiers: [.command, .option]) // Cmd+Opt+\
    static let defaultToggle = KeyBinding(keyCode: 5, modifiers: [.command, .shift]) // Cmd+Shift+G

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option)  { parts.append("Option") }
        if modifiers.contains(.shift)   { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(keyCodeName)
        return parts.joined(separator: " + ")
    }

    var keyCodeName: String {
        let names: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
            36: "Return", 76: "Enter",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 115: "Home",
            116: "PageUp", 117: "ForwardDelete", 119: "End", 120: "F2",
            121: "PageDown", 122: "F1", 123: "Left", 124: "Right",
            125: "Down", 126: "Up",
        ]
        return names[keyCode] ?? "Key\(keyCode)"
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

private extension Double {
    var nonZeroDouble: Double? { self == 0.0 ? nil : self }
}
