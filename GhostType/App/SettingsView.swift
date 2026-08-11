import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView(selection: $settings.settingsTab) {
            SetupSettingsView()
                .tabItem { Label("Setup", systemImage: "checklist") }
                .tag(SettingsTab.setup)

            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            ModelSettingsView()
                .tabItem { Label("Model", systemImage: "cpu") }
                .tag(SettingsTab.model)

            InferenceSettingsView()
                .tabItem { Label("Inference", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.inference)

            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag(SettingsTab.appearance)

            ExcludedAppsSettingsView()
                .tabItem { Label("Excluded Apps", systemImage: "xmark.app") }
                .tag(SettingsTab.excluded)
        }
        .frame(width: 560, height: 540)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var languageDirty = false

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: settings.preferredLanguage) ?? .system },
            set: { newValue in
                let changed = newValue.rawValue != settings.preferredLanguage
                settings.preferredLanguage = newValue.rawValue
                if changed { languageDirty = true }
            }
        )
    }

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: languageSelection) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                if languageDirty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Changing the language requires relaunching GhostType to take effect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Relaunch") { relaunchApp() }
                            .controlSize(.small)
                    }
                }
            }

            Section("Trigger") {
                Toggle("Auto-trigger completions", isOn: $settings.autoTrigger)
                HStack {
                    Text("Debounce delay")
                    Spacer()
                    TextField("ms", value: $settings.debounceMs, format: .number)
                        .frame(width: 80)
                    Text("ms")
                }
            }

            Section("Keyboard Shortcuts") {
                KeybindingRecordRow(label: "Accept completion", binding: $settings.keyAccept)
                KeybindingRecordRow(label: "Dismiss completion", binding: $settings.keyDismiss)
                KeybindingRecordRow(label: "Manual trigger", binding: $settings.keyManualTrigger)
                KeybindingRecordRow(label: "Toggle GhostType", binding: $settings.keyToggle)

                Picker("The accept key takes", selection: $settings.tabAcceptsWord) {
                    Text("One word").tag(true)
                    Text("The whole suggestion").tag(false)
                }
                Text("Holding Shift with the accept key always does the other one. Accepting a word at a time lets you stop partway through a long suggestion instead of deleting the rest.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.resetKeyBindingsToDefaults()
                    }
                    .controlSize(.small)
                }
            }

            Section("Try It") {
                Text("Type below to test completions. Pause typing to trigger, Tab to accept, Esc to dismiss.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                CompletionTestField(settings: settings)
                    .frame(height: 80)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Relaunch the app so a language change can take effect.
    /// We spawn a detached `open -n` on the bundle and quit ourselves;
    /// the new process picks up the updated `AppleLanguages` default.
    private func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}

struct KeybindingRecordRow: View {
    let label: LocalizedStringKey
    @Binding var binding: KeyBinding
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()

            if isRecording {
                Text("Press a key...")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
                    .overlay(
                        KeyRecorderRepresentable { keyCode, modifiers in
                            binding = KeyBinding(keyCode: keyCode, modifiers: modifiers)
                            isRecording = false
                        }
                        .frame(width: 0, height: 0)
                    )

                Button("Cancel") { isRecording = false }
                    .controlSize(.small)
            } else {
                Text(binding.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)

                Button("Record") { isRecording = true }
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Key Recorder (NSView-based for reliable key capture)

struct KeyRecorderRepresentable: NSViewRepresentable {
    let onRecord: (Int, Set<KeyBinding.ModifierKey>) -> Void

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.onRecord = onRecord
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderView, context: Context) {
        nsView.onRecord = onRecord
    }
}

final class KeyRecorderView: NSView {
    var onRecord: ((Int, Set<KeyBinding.ModifierKey>) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        var mods = Set<KeyBinding.ModifierKey>()
        if event.modifierFlags.contains(.command)  { mods.insert(.command) }
        if event.modifierFlags.contains(.option)   { mods.insert(.option) }
        if event.modifierFlags.contains(.shift)    { mods.insert(.shift) }
        if event.modifierFlags.contains(.control)  { mods.insert(.control) }

        onRecord?(Int(event.keyCode), mods)
    }
}

// MARK: - Model / Server

struct ModelSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var server = BundledLlamaServer.shared
    @ObservedObject private var styleStore = WritingStyleStore.shared
    @State private var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown, checking, connected, failed(String)
    }

    var body: some View {
        Form {
            Section("Inference Backend") {
                Picker("Run inference with", selection: $settings.backend) {
                    ForEach(LLMBackend.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(settings.backend.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if settings.backend == .embedded, !BundledLlamaServer.isAvailable {
                    Label("This build does not include the llama.cpp binaries. Run scripts/fetch-llama.sh and rebuild, or use an external server.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if settings.backend == .embedded {
                embeddedModelSection
                embeddedServerSection
            } else {
                externalServerSection
            }

            Section("Your Writing") {
                Toggle("Learn how I write", isOn: $settings.learnWritingStyle)
                Text("Keeps recent snippets of your own writing on this Mac and sends a few as context, so completions sound like you instead of like a generic assistant.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("\(styleStore.sampleCount) snippets stored")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Erase") { styleStore.clear() }
                        .controlSize(.small)
                        .disabled(styleStore.sampleCount == 0)
                }

                Text("Password fields, password managers, and sign-in pages are never recorded. Nothing is uploaded.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Section("Completion Style") {
                Picker("Shape", selection: $settings.grammarStyle) {
                    ForEach(CompletionGrammar.Style.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Text(settings.grammarStyle.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Constrains the sampler so the model cannot spend tokens on text GhostType would discard. Applies to the built-in backend and to any external llama.cpp server.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Embedded backend

    @ViewBuilder
    private var embeddedModelSection: some View {
        // Grouped so the choice reads as "what am I writing?" rather than a
        // flat list of model names the user has to already understand.
        ForEach([CatalogModel.Kind.prose, .code], id: \.self) { kind in
            Section(kind.sectionTitle) {
                ForEach(CatalogModel.models(ofKind: kind)) { model in
                    EmbeddedModelRow(
                        model: model,
                        isSelected: settings.embeddedModelID == model.id,
                        onSelect: { settings.embeddedModelID = model.id }
                    )
                }

                if kind == .code {
                    Text("Models are stored in ~/Library/Application Support/GhostType/models and never leave your Mac.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var embeddedServerSection: some View {
        Section("Server") {
            HStack(spacing: 6) {
                switch server.state {
                case .stopped:
                    Image(systemName: "moon.zzz").foregroundColor(.secondary)
                    Text("Idle. Starts on your first keystroke.").font(.caption).foregroundColor(.secondary)
                case .starting:
                    ProgressView().controlSize(.small)
                    Text("Loading the model...").font(.caption).foregroundColor(.secondary)
                case .running(let endpoint):
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Running on \(endpoint)").font(.caption).foregroundColor(.green)
                case .failed(let message):
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(message).font(.caption).foregroundColor(.red).lineLimit(3)
                }
                Spacer()
            }
        }
    }

    // MARK: - External backend

    @ViewBuilder
    private var externalServerSection: some View {
        Section("LLM Server") {
            Text("GhostType connects to an OpenAI-compatible API server.\nStart your LLM in LM Studio, Ollama, or any compatible app before using.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Server Endpoint", text: $settings.serverEndpoint)
                .font(.system(.body, design: .monospaced))
            TextField("Model Name (optional, auto-detected if blank)", text: $settings.modelName)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button("Test Connection") { testConnection() }

                Spacer()

                switch connectionStatus {
                case .unknown:
                    EmptyView()
                case .checking:
                    ProgressView().controlSize(.small)
                    Text("Connecting...").font(.caption).foregroundColor(.secondary)
                case .connected:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Connected").font(.caption).foregroundColor(.green)
                case .failed(let msg):
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(msg).font(.caption).foregroundColor(.red).lineLimit(2)
                }
            }
        }

        Section("Compatible Apps") {
            VStack(alignment: .leading, spacing: 6) {
                CompatibleAppRow(name: "LM Studio", endpoint: "http://127.0.0.1:1234", note: "GUI, easy model management")
                CompatibleAppRow(name: "Ollama", endpoint: "http://127.0.0.1:11434", note: "CLI, ollama serve")
                CompatibleAppRow(name: "llama.cpp", endpoint: "http://127.0.0.1:8080", note: "llama-server -m model.gguf")
                CompatibleAppRow(name: "vLLM / LocalAI", endpoint: "http://127.0.0.1:8000", note: "Advanced, high throughput")
            }
            Text("A llama.cpp server unlocks the same fill-in-the-middle and grammar path the built-in backend uses. GhostType detects it automatically.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }

        Section("Recommended Models (FIM-capable)") {
            VStack(alignment: .leading, spacing: 4) {
                ModelInfoRow(name: "Qwen2.5-Coder-3B", size: "~2GB", note: "Code & technical docs")
                ModelInfoRow(name: "DeepSeek-Coder-V2-Lite", size: "~2GB", note: "FIM-specialized, high quality")
                ModelInfoRow(name: "CodeGemma-2B", size: "~1.5GB", note: "Ultra-lightweight, low latency")
            }
        }
    }

    private func testConnection() {
        connectionStatus = .checking
        Task { @MainActor in
            let result = await AppDelegate.shared.completionEngine.probe()
            switch result {
            case .success(let models):
                connectionStatus = .connected
                if settings.modelName.isEmpty, let firstModel = models.first {
                    settings.modelName = firstModel
                }
            case .failure(let error):
                let message = (error as? LLMError)?.errorDescription
                    ?? String(localized: "Cannot connect. Is the server running?")
                connectionStatus = .failed(message)
            }
        }
    }
}

/// One row of the embedded-backend model list: pick it, fetch it, or delete it.
///
/// Download state lives in the shared `ModelDownloader` rather than in the row,
/// so navigating away from Settings mid-download does not cancel a 1.6 GB
/// transfer.
struct EmbeddedModelRow: View {
    let model: CatalogModel
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var downloader = ModelDownloader.shared
    @State private var installed: Bool = false
    @State private var errorText: String?

    private var isDownloadingThis: Bool {
        downloader.isDownloading && downloader.activeModelID == model.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                if installed {
                    Button {
                        onSelect()
                    } label: {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "circle.dotted").foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.displayName).font(.callout)
                    Text(model.summary).font(.caption2).foregroundColor(.secondary)
                }

                Spacer()

                Text(model.formattedSize).font(.caption2).foregroundColor(.secondary)

                if isDownloadingThis {
                    Button("Stop") { downloader.cancel() }
                        .controlSize(.small)
                } else if installed {
                    Button("Remove") { remove() }
                        .controlSize(.small)
                } else {
                    Button("Download") { download() }
                        .controlSize(.small)
                        .disabled(downloader.isDownloading)
                }
            }

            if isDownloadingThis {
                ProgressView(value: downloader.fractionCompleted ?? 0)
                    .controlSize(.small)
            }

            if let errorText {
                Text(errorText).font(.caption2).foregroundColor(.red).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .onAppear { installed = ModelStore.isInstalled(model) }
        .onChange(of: downloader.phase) { _ in
            installed = ModelStore.isInstalled(model)
        }
    }

    private func download() {
        errorText = nil
        Task {
            do {
                try await downloader.download(model)
                installed = ModelStore.isInstalled(model)
                // Downloading a model is an unambiguous statement of intent, so
                // adopt it rather than making the user pick it afterwards.
                if installed { onSelect() }
            } catch is CancellationError {
                // Stopping is a user action, not something to report back at them.
            } catch let error as ModelDownloadError {
                if case .cancelled = error { return }
                errorText = error.localizedDescription
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func remove() {
        do {
            try ModelStore.remove(model)
            installed = false
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct CompatibleAppRow: View {
    let name: String
    let endpoint: String
    let note: String

    var body: some View {
        HStack {
            Text(name).font(.caption).bold().frame(width: 80, alignment: .leading)
            Text(endpoint)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(note).font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct ModelInfoRow: View {
    let name: String
    let size: String
    let note: String

    var body: some View {
        HStack {
            Text(name).font(.caption).bold()
            Text(size).font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text(note).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Inference

struct InferenceSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Generation") {
                HStack {
                    Text("Max Tokens")
                    Spacer()
                    TextField("", value: $settings.maxTokens, format: .number)
                        .frame(width: 80)
                }
                HStack {
                    Text("Temperature")
                    Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", settings.temperature))
                        .frame(width: 30)
                }
                HStack {
                    Text("Top P")
                    Slider(value: $settings.topP, in: 0...1, step: 0.05)
                    Text(String(format: "%.2f", settings.topP))
                        .frame(width: 40)
                }
                HStack {
                    Text("Max Suggestion Length (chars)")
                    Spacer()
                    TextField("", value: $settings.maxCompletionChars, format: .number)
                        .frame(width: 80)
                }
                HStack {
                    Text("Repetition Penalty")
                    Slider(value: $settings.repeatPenalty, in: 1.0...1.5, step: 0.05)
                    Text(String(format: "%.2f", settings.repeatPenalty))
                        .frame(width: 40)
                }
                Text("1.00 disables it. Small models loop without it, repeating the same clause until they run out of tokens.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Section("Context") {
                HStack {
                    Text("Context Window (chars)")
                    Spacer()
                    TextField("", value: $settings.contextWindow, format: .number)
                        .frame(width: 80)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Ghost Text") {
                HStack {
                    Text("Opacity")
                    Slider(value: $settings.ghostTextOpacity, in: 0.1...1.0, step: 0.05)
                    Text(String(format: "%.0f%%", settings.ghostTextOpacity * 100))
                        .frame(width: 40)
                }
                HStack {
                    Text("Font Size")
                    Slider(value: $settings.fontSize, in: 9...24, step: 1)
                    Text(String(format: "%.0f", settings.fontSize))
                        .frame(width: 30)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Installed App Info

struct InstalledApp: Identifiable, Hashable {
    let id: String // bundleID
    let name: String
    let icon: NSImage

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
}

private func loadInstalledApps() -> [InstalledApp] {
    let workspace = NSWorkspace.shared
    let fileManager = FileManager.default
    let appDirs = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSString(string: "~/Applications").expandingTildeInPath
    ]
    var seen = Set<String>()
    var apps: [InstalledApp] = []

    for dir in appDirs {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
        for item in contents where item.hasSuffix(".app") {
            let path = (dir as NSString).appendingPathComponent(item)
            guard let bundle = Bundle(path: path),
                  let bundleID = bundle.bundleIdentifier,
                  !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? (item as NSString).deletingPathExtension
            let icon = workspace.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            apps.append(InstalledApp(id: bundleID, name: name, icon: icon))
        }
    }
    return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let installedApps: [InstalledApp]
    let alreadyAdded: Set<String>
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [InstalledApp] {
        let available = installedApps.filter { !alreadyAdded.contains($0.id) }
        if searchText.isEmpty { return available }
        let query = searchText.lowercased()
        return available.filter {
            $0.name.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Application")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filtered) { app in
                HStack(spacing: 8) {
                    Image(nsImage: app.icon)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                            .font(.body)
                        Text(app.id)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Add") {
                        onAdd(app.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(width: 480, height: 400)
    }
}

// MARK: - Excluded Apps

struct ExcludedAppsSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var installedApps: [InstalledApp] = []
    @State private var showExcludedPicker = false
    @State private var showManualOnlyPicker = false

    var body: some View {
        Form {
            Section("Excluded Applications") {
                Text("GhostType will not activate at all in these apps. IDEs and terminals are excluded by default (they have their own completions).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                BundleIDList(items: $settings.excludedBundleIDs, installedApps: installedApps)
                    .frame(minHeight: 80, maxHeight: 150)

                HStack {
                    Button("Add App...") { showExcludedPicker = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.excludedBundleIDs = AppSettings.defaultExcludedBundleIDs
                    }
                    .controlSize(.small)
                }
            }

            Section("Manual Trigger Only") {
                Text("In these apps, auto-trigger is disabled. Use the manual trigger shortcut (\(settings.keyManualTrigger.displayString)) to request completions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                BundleIDList(items: $settings.manualOnlyBundleIDs, installedApps: installedApps)
                    .frame(minHeight: 60, maxHeight: 120)

                HStack {
                    Button("Add App...") { showManualOnlyPicker = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.manualOnlyBundleIDs = AppSettings.defaultManualOnlyBundleIDs
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if installedApps.isEmpty {
                installedApps = loadInstalledApps()
            }
        }
        .sheet(isPresented: $showExcludedPicker) {
            AppPickerSheet(
                installedApps: installedApps,
                alreadyAdded: Set(settings.excludedBundleIDs)
            ) { bundleID in
                if !settings.excludedBundleIDs.contains(bundleID) {
                    settings.excludedBundleIDs.append(bundleID)
                }
            }
        }
        .sheet(isPresented: $showManualOnlyPicker) {
            AppPickerSheet(
                installedApps: installedApps,
                alreadyAdded: Set(settings.manualOnlyBundleIDs)
            ) { bundleID in
                if !settings.manualOnlyBundleIDs.contains(bundleID) {
                    settings.manualOnlyBundleIDs.append(bundleID)
                }
            }
        }
    }
}

struct BundleIDList: View {
    @Binding var items: [String]
    var installedApps: [InstalledApp]

    private func appInfo(for bundleID: String) -> InstalledApp? {
        installedApps.first { $0.id == bundleID }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Text("No apps added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                } else {
                    ForEach(items, id: \.self) { bundleID in
                        HStack(spacing: 8) {
                            if let app = appInfo(for: bundleID) {
                                Image(nsImage: app.icon)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.caption)
                                    Text(bundleID)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(bundleID)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            Spacer()
                            Button(role: .destructive) {
                                items.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(bundleID)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        if bundleID != items.last {
                            Divider()
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Completion Test Field

struct CompletionTestField: NSViewRepresentable {
    let settings: AppSettings

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.font = .monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.string = String(localized: "Type here to test completions...\n")
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 6, height: 6)

        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let settings: AppSettings
        private var debounceTimer: Timer?
        private var currentTask: Task<Void, Never>?
        private var ghostRange: NSRange?
        private var ghostText: String?

        init(settings: AppSettings) {
            self.settings = settings
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // If ghost text is showing, remove it on new input
            clearGhost(textView)

            // Reset debounce
            debounceTimer?.invalidate()
            currentTask?.cancel()

            guard settings.autoTrigger else { return }

            let interval = TimeInterval(settings.debounceMs) / 1000.0
            debounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.triggerCompletion(textView)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Tab: accept ghost text
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if let ghost = ghostText, let range = ghostRange {
                    // Ghost text is already in the string as gray text; just restyle it to normal
                    let storage = textView.textStorage!
                    storage.setAttributes(
                        [.font: textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                         .foregroundColor: NSColor.textColor],
                        range: range
                    )
                    // Move cursor to end of accepted text
                    textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
                    ghostRange = nil
                    ghostText = nil
                    return true
                }
                return false
            }

            // Esc: dismiss ghost text
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if ghostText != nil {
                    clearGhost(textView)
                    return true
                }
                return false
            }

            return false
        }

        private func triggerCompletion(_ textView: NSTextView) {
            let fullText = textView.string
            let cursorLocation = textView.selectedRange().location
            guard cursorLocation <= fullText.count else { return }

            let nsString = fullText as NSString
            let prefix = nsString.substring(to: cursorLocation)
            let suffix = nsString.substring(from: cursorLocation)

            guard !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            // Route the playground through the same engine the app uses, so
            // "try it here" exercises whichever backend is actually selected —
            // including the bundled server — instead of always testing the
            // external endpoint.
            currentTask?.cancel()
            currentTask = nil
            AppDelegate.shared.completionEngine.complete(
                prefix: prefix,
                suffix: suffix,
                isManual: true
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let text):
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        self.showGhost(textView, text: trimmed, at: cursorLocation)
                    case .failure(let error):
                        print("[GhostType Test] \(error.localizedDescription)")
                    }
                }
            }
        }

        private func showGhost(_ textView: NSTextView, text: String, at location: Int) {
            // Verify cursor hasn't moved
            guard textView.selectedRange().location == location else { return }

            let storage = textView.textStorage!
            let ghostAttrs: [NSAttributedString.Key: Any] = [
                .font: textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.systemGray.withAlphaComponent(CGFloat(settings.ghostTextOpacity))
            ]

            let ghostAttrStr = NSAttributedString(string: text, attributes: ghostAttrs)
            storage.insert(ghostAttrStr, at: location)

            ghostRange = NSRange(location: location, length: text.count)
            ghostText = text

            // Keep cursor before ghost text
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }

        private func clearGhost(_ textView: NSTextView) {
            guard let range = ghostRange else { return }
            let storage = textView.textStorage!
            if range.location + range.length <= storage.length {
                storage.deleteCharacters(in: range)
            }
            ghostRange = nil
            ghostText = nil
        }
    }
}

// MARK: - Setup Tab

struct SetupSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var accessibilityOK = false
    @State private var inputMonitoringOK = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var permissionCheckTimer: Timer?

    enum ConnectionStatus {
        case unknown, checking, connected, failed(String)
    }

    var body: some View {
        Form {
            Section {
                Text("Follow these steps to get GhostType running across all your apps.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("1. Choose where inference runs") {
                Picker("Backend", selection: $settings.backend) {
                    ForEach(LLMBackend.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(settings.backend.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if settings.backend == .embedded {
                    // The whole point of the built-in backend is that this
                    // screen ends with a working app, so the recommended model
                    // is downloadable right here rather than behind another tab.
                    EmbeddedModelRow(
                        model: CatalogModel.recommended,
                        isSelected: settings.embeddedModelID == CatalogModel.recommended.id,
                        onSelect: { settings.embeddedModelID = CatalogModel.recommended.id }
                    )
                    Text("Other sizes are in the Model tab.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    TextField("Endpoint", text: $settings.serverEndpoint)
                        .font(.system(.body, design: .monospaced))
                    TextField("Model (optional, auto-detect if blank)", text: $settings.modelName)
                        .font(.system(.body, design: .monospaced))

                    HStack {
                        Button("Test Connection") { testConnection() }

                        Spacer()

                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .checking:
                            ProgressView().controlSize(.small)
                        case .connected:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green).font(.caption)
                        case .failed(let msg):
                            Label(msg, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red).font(.caption).lineLimit(1)
                        }
                    }
                }
            }

            Section("2. Grant permissions") {
                permissionRow(
                    title: "Accessibility",
                    granted: accessibilityOK,
                    description: "Reads surrounding text and inserts accepted completions.",
                    openAction: AccessibilityManager.shared.openAccessibilitySettings
                )

                permissionRow(
                    title: "Input Monitoring",
                    granted: inputMonitoringOK,
                    description: "Observes your typing system-wide via CGEventTap.",
                    openAction: AccessibilityManager.shared.openInputMonitoringSettings
                )

                Text("Auto-trigger pauses while a non-ASCII IME (Japanese, Chinese, Korean, …) is active so it never fights your composition. Switch back to ABC / English to resume.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("3. Shortcuts") {
                shortcutRow(action: "Accept completion", binding: settings.keyAccept)
                shortcutRow(action: "Dismiss", binding: settings.keyDismiss)
                shortcutRow(action: "Manual trigger", binding: settings.keyManualTrigger)
                shortcutRow(action: "Toggle on/off", binding: settings.keyToggle)
            }

            Section {
                if accessibilityOK && inputMonitoringOK {
                    Label("All set. GhostType is ready to use in any app.",
                          systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Grant both permissions above to enable system-wide completions.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            refreshPermissions()
            startPermissionPolling()
        }
        .onDisappear { stopPermissionPolling() }
    }

    private func permissionRow(
        title: LocalizedStringKey,
        granted: Bool,
        description: LocalizedStringKey,
        openAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).bold()
                Spacer()
                if granted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.caption)
                } else {
                    Label("Required", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange).font(.caption)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)

            if !granted {
                Button("Open System Settings") { openAction() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func shortcutRow(action: LocalizedStringKey, binding: KeyBinding) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(binding.displayString)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
    }

    // MARK: - Helpers

    private func refreshPermissions() {
        accessibilityOK = AccessibilityManager.shared.checkAccessibility()
        inputMonitoringOK = AccessibilityManager.shared.checkInputMonitoring()
    }

    private func startPermissionPolling() {
        stopPermissionPolling()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            refreshPermissions()
        }
    }

    private func stopPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func testConnection() {
        connectionStatus = .checking
        Task { @MainActor in
            let result = await AppDelegate.shared.completionEngine.probe()
            switch result {
            case .success(let models):
                connectionStatus = .connected
                if settings.modelName.isEmpty, let firstModel = models.first {
                    settings.modelName = firstModel
                }
            case .failure(let error):
                let message = (error as? LLMError)?.errorDescription
                    ?? String(localized: "Cannot connect. Is the server running?")
                connectionStatus = .failed(message)
            }
        }
    }
}
