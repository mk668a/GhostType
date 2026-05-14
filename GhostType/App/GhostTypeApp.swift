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

// MARK: - App Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // LLM Server Settings
    @Published var serverEndpoint: String = "http://127.0.0.1:1234" {
        didSet { save() }
    }
    @Published var modelName: String = "" {
        didSet { save() }
    }

    // Inference Parameters
    @Published var maxTokens: Int = 64 {
        didSet { save() }
    }
    @Published var temperature: Double = 0.2 {
        didSet { save() }
    }
    @Published var topP: Double = 0.9 {
        didSet { save() }
    }
    @Published var contextWindow: Int = 512 {
        didSet { save() }
    }

    // Trigger Settings
    @Published var debounceMs: Int = 300 {
        didSet { save() }
    }
    @Published var autoTrigger: Bool = true {
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
        serverEndpoint = defaults.string(forKey: "serverEndpoint") ?? "http://127.0.0.1:1234"
        modelName = defaults.string(forKey: "modelName") ?? ""
        maxTokens = defaults.integer(forKey: "maxTokens").nonZero ?? 64
        temperature = defaults.double(forKey: "temperature").nonZeroDouble ?? 0.2
        topP = defaults.double(forKey: "topP").nonZeroDouble ?? 0.9
        contextWindow = defaults.integer(forKey: "contextWindow").nonZero ?? 512
        debounceMs = defaults.integer(forKey: "debounceMs").nonZero ?? 300
        autoTrigger = defaults.object(forKey: "autoTrigger") as? Bool ?? true
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
        defaults.set(serverEndpoint, forKey: "serverEndpoint")
        defaults.set(modelName, forKey: "modelName")
        defaults.set(maxTokens, forKey: "maxTokens")
        defaults.set(temperature, forKey: "temperature")
        defaults.set(topP, forKey: "topP")
        defaults.set(contextWindow, forKey: "contextWindow")
        defaults.set(debounceMs, forKey: "debounceMs")
        defaults.set(autoTrigger, forKey: "autoTrigger")
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
