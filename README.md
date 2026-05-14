<p align="center">
  <img src="images/header.png" alt="GhostType" width="600">
</p>

> 🇯🇵 [日本語版 README はこちら](docs/i18n/README.ja.md)

# GhostType

**AI-powered keyboard completion engine for macOS**

GhostType brings GitHub Copilot-style ghost text completions to **every app on macOS** -- text editors, browsers, email clients, and more. Powered by local LLMs, it provides context-aware completions while keeping your data completely private.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-PolyForm%20NC%201.0.0-blue" alt="PolyForm Noncommercial 1.0.0">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

## Features

- **System-wide completions** -- Works in any macOS text field (Safari, Notes, Mail, etc.)
- **Ghost text UI** -- Suggestions appear as translucent overlay text at your cursor
- **100% local** -- All inference runs on-device. No data ever leaves your Mac
- **Works with any OpenAI-compatible server** -- LM Studio, Ollama, llama.cpp, vLLM, etc.
- **Low latency** -- Optimized for fast response on Apple Silicon

## In Action

Ghost text completions appear right where you type — in any app.

<p align="center">
  <img src="images/usecase1.png" alt="GhostType in Gmail" width="600">
  <br>
  <em>Drafting a reply in Gmail</em>
</p>

<p align="center">
  <img src="images/usecase2.png" alt="GhostType on X" width="600">
  <br>
  <em>Composing a post on X</em>
</p>

## Install

### Download

Download the latest **GhostType-0.1.0.dmg** from the [Releases](https://github.com/mk668a/GhostType/releases) page.

### Install

1. Open the downloaded `.dmg` file
2. Drag **GhostType** into the **Applications** folder
3. Launch GhostType from Applications (or Spotlight)
4. Follow the setup guide that appears on first launch

> **Note:** macOS may show "unidentified developer" warning on first launch.
> Right-click the app > **Open** to bypass, or go to **System Settings > Privacy & Security** and click **Open Anyway**.

## Setup

### Step 1: Start a local LLM server

GhostType connects to a local LLM server that you run on your Mac. Choose one:

**[LM Studio](https://lmstudio.ai) (recommended):**
1. Download and install LM Studio
2. Search and download a model (e.g., `Qwen2.5-Coder-3B`)
3. Click "Start Server" (runs at `http://127.0.0.1:1234`)

**[Ollama](https://ollama.com):**
1. Download and install Ollama
2. Open Terminal and run:
   ```
   ollama pull qwen2.5-coder:3b
   ```
3. Ollama runs automatically at `http://127.0.0.1:11434`

### Step 2: Grant required permissions

GhostType needs both permissions:

- **Input Monitoring**: detect keystrokes via `NSEvent.addGlobalMonitorForEvents`
- **Accessibility**: read surrounding text and insert accepted completions via AX APIs

Enable GhostType in:

- **System Settings > Privacy & Security > Input Monitoring**
- **System Settings > Privacy & Security > Accessibility**

> The menu bar icon may show "Grant Input Monitoring" or "Grant Accessibility" until setup is complete.

### Step 3: Configure GhostType

1. Click the GhostType icon in the menu bar
2. Open **Settings**
3. Enter the server endpoint (e.g., `http://127.0.0.1:1234`)
4. Click **Test Connection** to verify

## How It Works

```
You type:  "The meeting covered "
           (pause)
GhostType: "The meeting covered quarterly sales targets and the product roadmap"
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                 Ghost text appears -- press Tab to accept
```

1. GhostType monitors your keystrokes via Input Monitoring
2. When you pause typing, it reads the surrounding text via Accessibility API
3. The text is sent to your local LLM server for completion
4. The suggestion appears as ghost text near your cursor
5. Press **Tab** to accept or **Esc** to dismiss

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Tab` | Accept completion |
| `Esc` | Dismiss completion |
| `Option + \` | Manually trigger completion |
| `Cmd + Shift + G` | Toggle GhostType on/off |

All shortcuts are customizable in Settings.

## Compatible LLM Servers

| App | Default Endpoint | Notes |
|-----|-----------------|-------|
| **[LM Studio](https://lmstudio.ai)** | `http://127.0.0.1:1234` | GUI, easy model management |
| **[Ollama](https://ollama.com)** | `http://127.0.0.1:11434` | Lightweight, CLI |
| **llama.cpp** | `http://127.0.0.1:8080` | Advanced users |
| **vLLM / LocalAI** | `http://127.0.0.1:8000` | High throughput |

### Recommended Models

| Model | Size | Strengths |
|-------|------|-----------|
| Qwen2.5-Coder-3B | ~2 GB | Code & technical writing |
| DeepSeek-Coder-V2-Lite | ~2 GB | FIM-specialized, high quality |
| CodeGemma-2B | ~1.5 GB | Ultra-lightweight, low latency |

## Settings

Click the menu bar icon > **Settings** to configure:

- **Server** -- Endpoint URL and model name
- **Inference** -- Temperature, max tokens, top-p
- **Trigger** -- Auto/manual trigger, debounce delay
- **Appearance** -- Ghost text opacity and font size
- **Keyboard Shortcuts** -- Customize all key bindings
- **Excluded Apps** -- Disable in specific applications (IDEs/terminals excluded by default)

## App Compatibility

GhostType works with most macOS apps. Some notes:

| App Type | Auto-trigger | Notes |
|----------|-------------|-------|
| TextEdit, Notes, Pages | Yes | Full support via Accessibility API |
| Safari, Chrome (web inputs) | Yes | Uses keystroke buffer as fallback |
| Mail, Slack, Discord | Manual only | Use `Option + \` to trigger |
| IDEs, Terminals | Disabled | These have their own completions |

## System Requirements

| | Minimum | Recommended |
|--|---------|-------------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **CPU** | Apple M1 / Intel i7 | Apple M2 Pro+ |
| **RAM** | 8 GB | 16 GB+ |
| **Storage** | 5 GB (with model) | 10 GB+ |

## Privacy & Security

- Connects **only to your local LLM server** (`127.0.0.1`). No cloud, no telemetry
- No input logging or data collection
- Accessibility permission is requested on first launch
- All completions are generated on your Mac by your own LLM

## Troubleshooting

**Completions don't appear in external apps:**
1. Check the menu bar status:
   - If it shows "Grant Accessibility", open System Settings > Privacy & Security > Accessibility and toggle GhostType ON
   - If it shows "Grant Input Monitoring", open System Settings > Privacy & Security > Input Monitoring and toggle GhostType ON
2. After granting permission, GhostType automatically restarts within a few seconds
3. If status still does not become "Ready", try quitting and relaunching GhostType
4. When building from source, re-granting Accessibility may be needed after each build (code signature changes)

**Completions work in Settings test field but not in other apps:**
- This means Accessibility permission is not granted. The test field uses a direct connection that doesn't need system permission, but external apps do.

**No ghost text appears even though status is "Ready":**
- Make sure your LLM server is running (test connection in Settings)
- Try the manual trigger shortcut (`Option + \`)
- Check if the app is in the Excluded Apps list

## Uninstall

1. Quit GhostType from the menu bar
2. Drag GhostType from Applications to Trash
3. Optionally remove settings: delete `~/Library/Preferences/com.ghosttype.app.plist`

## Build from Source

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType

# Build DMG installer
./scripts/create-dmg.sh

# Or install directly
./scripts/install.sh

# Or open in Xcode
open GhostType.xcodeproj
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## Architecture

```
GhostType/
├── App/
│   ├── GhostTypeApp.swift          # App entry point & settings
│   ├── AppDelegate.swift           # Menu bar, lifecycle, completion flow
│   ├── SettingsView.swift          # Preferences UI
│   └── WelcomeView.swift           # First-launch setup guide
├── Core/
│   ├── AccessibilityManager.swift  # AX API text read/write, permissions
│   ├── EventTapManager.swift       # NSEvent global/local keystroke monitoring
│   └── CompletionEngine.swift      # LLM completion orchestration
├── LLM/
│   └── LLMProvider.swift           # OpenAI-compatible API client
└── UI/
    ├── OverlayWindow.swift         # Ghost text overlay window
    └── CompletionPopup.swift       # Multi-suggestion popup
```

## License

[PolyForm Noncommercial License 1.0.0](LICENSE).

GhostType is **source-available** software, not Open Source by the OSI definition. Personal, educational, research, and noncommercial-organization use is permitted free of charge. **Commercial use is not permitted** under this license — please contact the maintainers if you need a commercial license.

---

**GhostType** -- *Type less. Think more.*
