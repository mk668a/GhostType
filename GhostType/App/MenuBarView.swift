import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button(settings.isEnabled ? "Disable GhostType" : "Enable GhostType") {
            settings.isEnabled.toggle()
        }

        Divider()

        Text("Status: \(settings.statusText)")
        Text("Server: \(settings.serverEndpoint)")
            .font(.system(size: 11, design: .monospaced))

        Divider()

        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Setup Guide...") {
            AppDelegate.shared.openSettings(initialTab: .setup)
        }

        Divider()

        Button("Quit GhostType") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
