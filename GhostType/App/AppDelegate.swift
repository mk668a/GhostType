import AppKit
import SwiftUI
import Combine
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    let settings = AppSettings.shared

    private var statusItem: NSStatusItem!
    private(set) var completionEngine: CompletionEngine!
    private(set) var overlayWindow: OverlayWindowController!
    private var keyMonitor: GlobalKeyMonitor!
    private var completionController: CompletionController!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    /// Drives Sparkle auto-updates. Started immediately on launch so the
    /// scheduled check (controlled by SUScheduledCheckInterval in Info.plist)
    /// runs in the background; the menu's "Check for Updates…" item invokes
    /// `checkForUpdates(_:)` on this controller for manual checks.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Menu-bar-only accessory app
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupCompletionEngine()
        setupOverlay()
        setupKeyMonitor()

        // Both Accessibility (AX I/O) and Input Monitoring (CGEventTap)
        // are required. The Setup tab in Settings walks the user through them.
        if settings.isFirstLaunch {
            if !AccessibilityManager.shared.checkAccessibility() {
                AccessibilityManager.shared.requestAccessibility()
            }
            openSettings(initialTab: .setup)
        }

        settings.statusText = String(localized: "Ready")
        settings.markLaunched()
    }

    // MARK: - Key Monitor + Completion Controller

    private func setupKeyMonitor() {
        // Touch the input source monitor so it starts observing notifications.
        _ = InputSourceMonitor.shared

        keyMonitor = GlobalKeyMonitor()
        completionController = CompletionController(
            settings: settings,
            engine: completionEngine,
            overlay: overlayWindow,
            keyMonitor: keyMonitor,
            inputSource: InputSourceMonitor.shared
        )

        if !keyMonitor.start() {
            print("[GhostType] Failed to start event tap. The user likely needs to grant Accessibility permission.")
        }
    }

    // MARK: - Menu Bar (NSStatusItem)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        updateStatusItemIcon()
        rebuildMenu()

        settings.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        settings.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        settings.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemIcon()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    /// Swap the menu bar SF Symbol so a glance at the icon tells the user
    /// whether GhostType can reach its LLM endpoint.
    private func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch settings.connectionState {
        case .unreachable, .suppressed:
            symbolName = "exclamationmark.bubble"
        case .ok, .unknown:
            symbolName = "text.bubble"
        }
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "GhostType") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "G"
        }
        button.toolTip = "GhostType — \(connectionStateLabel())"
    }

    private func connectionStateLabel() -> String {
        switch settings.connectionState {
        case .unknown:     return String(localized: "Unknown")
        case .ok:          return String(localized: "Connected")
        case .suppressed:  return String(localized: "Paused")
        case .unreachable: return String(localized: "Disconnected")
        }
    }

    /// Colored dot image used as an NSMenuItem icon to visualize connection state.
    private func connectionStateDot() -> NSImage? {
        let color: NSColor
        switch settings.connectionState {
        case .ok:          color = .systemGreen
        case .suppressed:  color = .systemYellow
        case .unreachable: color = .systemRed
        case .unknown:     color = .tertiaryLabelColor
        }
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            .applying(.init(paletteColors: [color]))
        let base = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        return base?.withSymbolConfiguration(config)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let enableItem = NSMenuItem(
            title: settings.isEnabled
                ? String(localized: "Disable GhostType")
                : String(localized: "Enable GhostType"),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.target = self
        if settings.isEnabled {
            enableItem.image = NSImage(systemSymbolName: "checkmark.circle.fill",
                                       accessibilityDescription: nil)
        } else {
            enableItem.image = NSImage(systemSymbolName: "circle",
                                       accessibilityDescription: nil)
        }
        menu.addItem(enableItem)

        menu.addItem(.separator())

        let connTitle = String(localized: "Connection: \(connectionStateLabel())")
        let connItem = NSMenuItem(title: connTitle, action: nil, keyEquivalent: "")
        connItem.isEnabled = false
        connItem.image = connectionStateDot()
        menu.addItem(connItem)

        let statusTitle = String(localized: "Status: \(settings.statusText)")
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let serverTitle = String(localized: "Server: \(settings.serverEndpoint)")
        let serverItem = NSMenuItem(title: serverTitle, action: nil, keyEquivalent: "")
        serverItem.isEnabled = false
        serverItem.attributedTitle = NSAttributedString(
            string: serverTitle,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                         .foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(serverItem)

        let axOK = AccessibilityManager.shared.checkAccessibility()
        let tapOK = keyMonitor?.isRunning ?? false
        let imeASCII = InputSourceMonitor.shared.isASCIICompatible

        let diagText = "AX: \(axOK ? "OK" : "NO")  Tap: \(tapOK ? "ON" : "OFF")  IME: \(imeASCII ? "ASCII" : "non-ASCII")"
        let diagItem = NSMenuItem(title: diagText, action: nil, keyEquivalent: "")
        diagItem.isEnabled = false
        diagItem.attributedTitle = NSAttributedString(
            string: diagText,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                         .foregroundColor: NSColor.tertiaryLabelColor]
        )
        menu.addItem(diagItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettingsAction(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: String(localized: "Check for Updates..."),
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit GhostType"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        self.statusItem.button?.appearsDisabled = !settings.isEnabled
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func openSettingsAction(_ sender: Any?) {
        openSettings(initialTab: nil)
    }

    /// Shows the Settings window. macOS 14+ no longer lets us open the
    /// SwiftUI Settings scene from AppKit (requires SettingsLink), so we
    /// host SettingsView in an AppDelegate-managed NSWindow ourselves.
    func openSettings(initialTab: SettingsTab?) {
        if let tab = initialTab {
            settings.settingsTab = tab
        }

        if settingsWindow == nil {
            let root = SettingsView().environmentObject(settings)
            let controller = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "GhostType Settings")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Core Setup

    private func setupCompletionEngine() {
        completionEngine = CompletionEngine(settings: settings)
    }

    private func setupOverlay() {
        overlayWindow = OverlayWindowController(settings: settings)
    }
}
