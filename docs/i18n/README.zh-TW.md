<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · 繁體中文 · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md)

# GhostType

**為 Mac 上每一個文字欄位加上 Tab 自動完成，全部在你自己的電腦上執行。**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="打字停頓後，游標處浮出灰色提示文字，按 Tab 採用" width="760">
</p>

GhostType 是閉源 Mac 自動完成工具 [Cotypist](https://cotypist.app/) 的免費替代品，採用 MIT 授權。

## 你熟悉的場景

你在 Gmail 裡回信，已經寫了三句。這句話該怎麼收尾你心裡有數，但還是得一個字一個字打完。

編輯器早就解決了這件事：GitHub Copilot 用灰字顯示這一行剩下的部分，你按 Tab 就好。可是郵件、Slack、備忘錄，還有你每天真正待著的瀏覽器輸入框，都沒有這種東西。

## GhostType 做什麼

你停下打字。游標處浮出灰色文字。按 `Tab`。

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

這是內建模型實際回傳的補完結果。在 Safari、備忘錄、郵件、Slack 以及任何 macOS 文字欄位裡，表現都一樣。

<p align="center">
  <img src="../../images/usecase1.png" alt="在 Gmail 中使用 GhostType" width="600">
  <br>
  <em>在 Gmail 裡寫回信</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="在 X 上使用 GhostType" width="600">
  <br>
  <em>在 X 上寫貼文</em>
</p>

## 兩種執行方式

這一點是多數本地 AI Mac 應用做錯的地方。它們打包一個模型，而如果你本來就跑著一個，同一份權重就會在記憶體裡存在兩份。GhostType 讓你自己選。

| | 內建 | 外部伺服器 |
|---|---|---|
| **準備工作** | 在設定裡下載模型。其他什麼都不用裝。 | 把 GhostType 指向你已經在跑的伺服器。 |
| **執行的是** | 應用程式內附的 `llama-server` | LM Studio、Ollama、llama.cpp、vLLM、LocalAI |
| **記憶體中的模型** | 一份，由 GhostType 載入 | 不額外佔用，重複使用已載入的。 |
| **適合** | 「我只想讓它能用。」 | 「我已經跑著 32B 模型了，就用那個。」 |

兩條路徑最終都通往同一個 OpenAI 相容的 HTTP 端點，所以這不是把兩個產品硬湊在一起。唯一的差別是誰管這個伺服器行程。

如果你的外部伺服器剛好就是 `llama-server`，GhostType 會自動辨識，並啟用與內建後端相同的高品質補完路徑。詳細意義請見[補完品質](#補完品質)。

## 安裝

在 [Releases](https://github.com/mk668a/GhostType/releases) 頁面下載最新的 `.dmg`，開啟後把 **GhostType** 拖進 **應用程式**。

### 首次啟動時的放行

GhostType 沒有經過 Apple 公證。公證需要付費的 Apple Developer 帳號，本專案沒有，所以 macOS 會擋下第一次啟動，要求你手動放行。這一步只需要做一次。

1. 開啟 **GhostType**。macOS 拒絕啟動，說無法驗證開發者。
2. 開啟 **系統設定 > 隱私權與安全性**，往下捲到 **安全性**。
3. 在關於 GhostType 被封鎖的訊息旁邊，按 **強制打開**，再按 **打開** 確認。

> 在 macOS 15 Sequoia 之後的版本，按住 Control 點應用程式再選 **打開** 已經沒有用了。Apple 移除了這個捷徑，只能走系統設定。

之後 GhostType 自己安裝的更新不會再觸發這個檢查。這道檢查針對的是下載來的應用程式的首次啟動，而不是就地更新的應用程式。

想完全跳過這一步，就[自己編譯](#從原始碼編譯)。自己編譯出來的應用程式從未被下載過，不帶隔離標記，啟動時完全不會有提示。

## 設定

### 步驟 1：選擇後端

安裝導引會在首次啟動時開啟。選 **內建** 並下載模型，或選 **外部伺服器** 並填入位址。

內建模型。寫作用的是基礎模型，而不是針對對話調校的版本，因為讓對話模型接續一句話，它往往會回答你而不是接著寫：

| 模型 | 大小 | 用途 | 說明 |
|------|------|------|------|
| Qwen3.5 0.8B Base | 約 0.6 GB | 寫作 | 最快。8 GB 記憶體的 Mac 也夠用。 |
| Qwen3.5 2B Base | 約 1.3 GB | 寫作 | 推薦。速度與品質最平衡。 |
| Qwen3.5 4B Base | 約 2.7 GB | 寫作 | 品質最好。建議 16 GB 以上記憶體。 |
| Qwen2.5-Coder 0.5B | 約 0.5 GB | 程式碼 | 輕量，適合程式碼與技術文件。 |
| Qwen2.5-Coder 1.5B | 約 1.6 GB | 程式碼 | 寫程式更強，寫日常文字較弱。 |

模型會下載到 `~/Library/Application Support/GhostType/models`，絕不會離開你的 Mac。

### 步驟 2：授予兩項權限

兩項都需要：

- **輸入監控**，用來察覺你停止打字
- **輔助使用**，用來讀取游標周圍的文字並插入你採用的內容

在 **系統設定 > 隱私權與安全性** 裡分別為 GhostType 開啟。選單列圖示會告訴你還缺哪一項。

### 步驟 3：隨便打點字

開啟文字編輯，寫半句話，然後停一下。灰色文字出現。按 `Tab`。

## 補完品質

一則補完你是採用還是刪掉，差別主要來自兩件事。

**中間填充（fill-in-the-middle）。** 大多數自動完成工具只把游標之前的文字送給模型。模型並不知道你後面還有內容，於是在你已有的結尾之上又寫了一個結尾。GhostType 透過 llama.cpp 的 `/infill` 端點把游標兩側的文字都送過去，補完因此落在句子**內部**，而不是把句尾重講一遍。

**受限生成。** 讓模型補完一句話，它有時會回一段程式碼區塊、把你的話複述一遍，或寫出三段解釋。事後再清理只能用猜的。GhostType 的做法是編譯一份 GBNF 文法交給取樣器，讓那些 token 從一開始就取不到。模型不會把時間花在注定要丟掉的文字上。

| 設定 | 文法限制 | 適用場景 |
|------|----------|----------|
| 單行 | 禁止換行與開頭的程式碼區塊標記 | 郵件、聊天、瀏覽器輸入框（預設） |
| 最多數行 | 最多允許 4 行 | 編輯器、筆記、多行輸入框 |
| 不限制 | 無 | 某個模型在限制下表現異常時 |

這兩項都需要伺服器支援 llama.cpp 的 API。內建後端一定滿足，外部的 `llama-server` 也滿足。面對一般的 OpenAI 相容伺服器時，GhostType 會退回到帶游標標記的 chat completions，仍然可用，但明顯粗糙一些。

## 鍵盤快速鍵

| 按鍵 | 動作 |
|------|------|
| `Tab` | 採用補完 |
| `Esc` | 關閉補完 |
| `Cmd + Option + \` | 手動觸發一次補完 |
| `Cmd + Shift + G` | 開關 GhostType |

所有快速鍵都可以在設定裡修改。

## 應用程式相容性

| 應用程式類型 | 自動觸發 | 原因 |
|--------------|----------|------|
| 文字編輯、備忘錄、Pages | 支援 | 完整支援輔助使用 API |
| Safari、Chrome 的網頁輸入框 | 支援 | 退回到按鍵緩衝區 |
| 郵件、Slack、Discord | 僅手動 | 自動觸發會與它們自己的輸入處理衝突 |
| IDE、終端機 | 關閉 | 它們本來就有補完 |

當非 ASCII 輸入法（中文、日文、韓文）正在組字時，自動觸發也會暫停，因此不會打斷你的轉換過程。

## 它不做什麼

- 不做雲端推論。這裡沒有填 API key 的地方，因為根本沒有要連的 API。
- 不做遙測、不做分析、不記錄輸入。
- 不需要帳號、不需要訂閱、沒有用量上限。
- 它不改寫、不翻譯、不重組你的文字。它只是把你起的頭寫完。

## 系統需求

| | 最低 | 建議 |
|--|------|------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **晶片** | Apple M1 | Apple M2 Pro 或更好 |
| **記憶體** | 8 GB | 16 GB 以上 |
| **儲存空間** | 1 GB 加上模型大小 | 5 GB |

## 隱私

每一則補完都在你的 Mac 上產生。內建後端連接 `127.0.0.1` 上的 `llama-server` 行程；外部後端連接你自己設定的回送位址。除了檢查自身更新，GhostType 不發出任何其他網路請求。

## 遇到問題時

**系統設定裡開關是開著的，GhostType 卻說沒有權限。**
從 0.3.1 或更早版本升級上來的人都會遇到這個。macOS 把每一次輔助使用授權，綁定到接受授權的那個應用程式的程式碼簽章上。0.3.1 之前的每個版本都用建置本身的雜湊值簽章，所以每換一個版本簽章就變一次。1.0.0 改用固定的憑證，到此為止，但你的 Mac 裡仍然存著舊規則。撥動開關只會更新授權狀態，不會重寫附在上面的規則，於是開關看起來是開的，應用程式卻一直被拒絕。

關掉再打開沒用，用減號把 GhostType 從清單裡移除也沒用。必須刪掉存下來的那筆記錄：

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

然後重新啟動 GhostType，在它詢問時授權。只需要做一次。想確認自己是不是這種情況，看下面的日誌裡有沒有 `Failed to match existing code requirement`：

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**在其他應用程式裡不出補完。**
看選單列狀態。如果顯示需要授予輔助使用或輸入監控，就到系統設定對應的面板把 GhostType 開啟，它會在幾秒內自動重新啟動。從原始碼編譯會重新簽章；如果編譯時沒有指定簽章身分，簽章每次都會變，於是每編譯一次 macOS 就要你重新授權一次輔助使用。執行一次 `scripts/make-signing-cert.sh`，之後帶著 `GHOSTTYPE_SIGN_IDENTITY` 編譯，權限就能跨重新編譯保留。

**在設定裡的測試欄位可以用，其他地方不行。**
這正好是缺輔助使用權限。測試欄位在 GhostType 內部，不需要系統權限。

**狀態顯示 Ready，但不出灰字。**
確認模型已下載（內建）或伺服器正在執行（外部）。試試手動快速鍵。再看看這個應用程式是不是在排除清單裡。

**內建後端說找不到 llama.cpp 的執行檔。**
你執行的是沒有包含它們的建置。執行 `scripts/fetch-llama.sh` 後重新編譯，或改用外部伺服器。

## 從原始碼編譯

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

首次建置時會自動取得鎖定版本的 llama.cpp 執行檔並放進應用程式套件，所以沒有另外的準備步驟。想手動取得，或要為 Intel 建置：

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

其他指令稿：

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

需要 Xcode 與命令列工具（`xcode-select --install`）。

## 結構

```
GhostType/
├── App/
│   ├── GhostTypeApp.swift          # Entry point, AppSettings, backend enum
│   ├── AppDelegate.swift           # Menu bar, lifecycle, server teardown
│   ├── SettingsView.swift          # Preferences and setup guide
│   └── MenuBarView.swift           # Status menu
├── Core/
│   ├── AccessibilityManager.swift  # AX text read/write, permissions
│   ├── GlobalKeyMonitor.swift      # CGEventTap keystroke monitoring
│   ├── InputSourceMonitor.swift    # IME state, pauses auto-trigger
│   ├── CompletionController.swift  # Debounce, ghost text lifecycle
│   └── CompletionEngine.swift      # Backend selection, circuit breaker
├── LLM/
│   ├── LLMProvider.swift           # HTTP client, /infill and chat paths
│   ├── BundledLlamaServer.swift    # Supervises the bundled llama-server
│   ├── ModelCatalog.swift          # Downloadable models, on-disk layout
│   ├── ModelDownloader.swift       # Resumable downloads with progress
│   └── CompletionGrammar.swift     # GBNF construction
└── UI/
    ├── OverlayWindow.swift         # Ghost text overlay window
    └── CompletionPopup.swift       # Multi-suggestion popup
```

## 致謝

推論由 [llama.cpp](https://github.com/ggml-org/llama.cpp)（MIT）驅動。寫作模型是 [mradermacher](https://huggingface.co/mradermacher) 轉換的 Qwen3.5 Base GGUF，程式碼模型是 [ggml-org](https://huggingface.co/ggml-org) 轉換的 [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder)。兩個模型系列皆為 Apache-2.0。

## 授權

[MIT](../../LICENSE)。隨便用、隨便 fork、拿去做商業產品也可以。沒有附加條件。

---

**GhostType** *Type less. Think more.*
