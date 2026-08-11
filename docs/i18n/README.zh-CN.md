<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · 简体中文 · [繁體中文](README.zh-TW.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md)

# GhostType

**给 Mac 上每一个输入框加上 Tab 补全，全部在你自己的电脑上运行。**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="打字停顿后，光标处出现灰色提示文字，按 Tab 采纳" width="760">
</p>

GhostType 是闭源 Mac 补全工具 [Cotypist](https://cotypist.app/) 的免费替代品，采用 MIT 许可证。

## 你熟悉的场景

你在 Gmail 里回信，已经写了三句。你心里清楚这句话该怎么收尾，但还是得一个字一个字敲完。

编辑器早就解决了这个问题：GitHub Copilot 用灰字显示这一行的剩余部分，你按 Tab 就行。可是邮件、Slack、备忘录，还有你每天真正泡在里面的浏览器输入框，都没有这样的东西。

## GhostType 做什么

你停下打字。光标处浮出灰色文字。按 `Tab`。

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

这是内置模型真实返回的补全结果。在 Safari、备忘录、邮件、Slack 以及任何 macOS 输入框里，表现都一样。

<p align="center">
  <img src="../../images/usecase1.png" alt="在 Gmail 中使用 GhostType" width="600">
  <br>
  <em>在 Gmail 里写回信</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="在 X 上使用 GhostType" width="600">
  <br>
  <em>在 X 上写帖子</em>
</p>

## 两种运行方式

这一点是多数本地 AI Mac 应用做错的地方。它们打包一个模型，而如果你本来就跑着一个，同一份权重就会在内存里存在两份。GhostType 让你自己选。

| | 内置 | 外部服务器 |
|---|---|---|
| **准备工作** | 在设置里下载模型。别的什么都不用装。 | 把 GhostType 指向你已经在跑的服务器。 |
| **运行的是** | 应用内打包的 `llama-server` | LM Studio、Ollama、llama.cpp、vLLM、LocalAI |
| **内存中的模型** | 一份，由 GhostType 加载 | 不额外占用，复用已经加载好的。 |
| **适合** | 「我只想让它能用。」 | 「我已经跑着 32B 模型了，就用那个。」 |

两条路径最终都通向同一个 OpenAI 兼容的 HTTP 接口，所以这不是把两个产品硬拼在一起。唯一的区别是谁来管这个服务进程。

如果你的外部服务器恰好就是 `llama-server`，GhostType 会自动识别，并启用与内置后端相同的高质量补全路径。具体含义见[补全质量](#补全质量)。

## 安装

在 [Releases](https://github.com/mk668a/GhostType/releases) 页面下载最新的 `.dmg`，打开后把 **GhostType** 拖进 **应用程序**。

### 首次启动时的放行

GhostType 没有经过 Apple 公证。公证需要付费的 Apple Developer 账号，本项目没有，所以 macOS 会拦下第一次启动，要求你手动放行。这一步只需做一次。

1. 打开 **GhostType**。macOS 拒绝启动，提示无法验证开发者。
2. 打开 **系统设置 > 隐私与安全性**，向下滚动到 **安全性**。
3. 在关于 GhostType 被阻止的提示旁边，点 **仍要打开**，再点 **打开** 确认。

> 在 macOS 15 Sequoia 及以后的版本上，按住 Control 点击应用再选 **打开** 已经不管用了。Apple 移除了这个快捷方式，只能走系统设置。

之后 GhostType 自己安装的更新不会再触发这个检查。这道检查针对的是下载来的应用的首次启动，而不是就地更新的应用。

想完全跳过这一步，就[自己编译](#从源码编译)。自己编译出来的应用从未被下载过，不带隔离标记，启动时不会有任何提示。

## 设置

### 第 1 步：选择后端

安装向导会在首次启动时打开。选 **内置** 并下载模型，或选 **外部服务器** 并填入地址。

内置模型。写作用的是基础模型，而不是面向对话调优的版本，因为让对话模型续写一句话，它往往会回答你而不是接着写：

| 模型 | 大小 | 用途 | 说明 |
|------|------|------|------|
| Qwen3.5 0.8B Base | 约 0.6 GB | 写作 | 最快。8 GB 内存的 Mac 也够用。 |
| Qwen3.5 2B Base | 约 1.3 GB | 写作 | 推荐。速度与质量最平衡。 |
| Qwen3.5 4B Base | 约 2.7 GB | 写作 | 质量最好。建议 16 GB 以上内存。 |
| Qwen2.5-Coder 0.5B | 约 0.5 GB | 代码 | 轻量，适合代码和技术文档。 |
| Qwen2.5-Coder 1.5B | 约 1.6 GB | 代码 | 写代码更强，写日常文字更弱。 |

模型下载到 `~/Library/Application Support/GhostType/models`，绝不会离开你的 Mac。

### 第 2 步：授予两项权限

两项都需要：

- **输入监控**，用来察觉你停止了打字
- **辅助功能**，用来读取光标周围的文字并插入你采纳的内容

在 **系统设置 > 隐私与安全性** 里分别为 GhostType 打开。菜单栏图标会告诉你还差哪一项。

### 第 3 步：随便打点字

打开文本编辑，写半句话，然后停一下。灰色文字出现。按 `Tab`。

## 补全质量

一条补全你是采纳还是删掉，差别主要来自两件事。

**中间填充（fill-in-the-middle）。** 大多数补全工具只把光标之前的文字发给模型。模型并不知道你后面还有内容，于是在你已有的结尾之上又写了一个结尾。GhostType 通过 llama.cpp 的 `/infill` 接口把光标两侧的文字都发过去，补全因此落在句子**内部**，而不是把句尾复述一遍。

**受约束生成。** 让模型补全一句话，它有时会回一段代码块、把你的话重述一遍，或者写出三段解释。事后再清理只能靠猜。GhostType 的做法是编译一份 GBNF 语法交给采样器，让那些 token 从一开始就取不到。模型不会把时间花在注定要被丢掉的文字上。

| 设置 | 语法约束 | 适用场景 |
|------|----------|----------|
| 单行 | 禁止换行和开头的代码块标记 | 邮件、聊天、浏览器输入框（默认） |
| 最多数行 | 最多允许 4 行 | 编辑器、笔记、多行输入框 |
| 不约束 | 无 | 某个模型在约束下表现异常时 |

这两项都需要服务器支持 llama.cpp 的 API。内置后端始终满足，外部的 `llama-server` 也满足。面对普通的 OpenAI 兼容服务器时，GhostType 会退回到带光标标记的 chat completions，仍然能用，但明显粗糙一些。

## 键盘快捷键

| 按键 | 动作 |
|------|------|
| `Tab` | 采纳补全 |
| `Esc` | 关闭补全 |
| `Cmd + Option + \` | 手动触发一次补全 |
| `Cmd + Shift + G` | 开关 GhostType |

所有快捷键都可以在设置里改。

## 应用兼容性

| 应用类型 | 自动触发 | 原因 |
|----------|----------|------|
| 文本编辑、备忘录、Pages | 支持 | 完整支持辅助功能 API |
| Safari、Chrome 的网页输入框 | 支持 | 退回到按键缓冲区 |
| 邮件、Slack、Discord | 仅手动 | 自动触发会和它们自己的输入处理打架 |
| IDE、终端 | 关闭 | 它们本来就有补全 |

当非 ASCII 输入法（中文、日文、韩文）正在组字时，自动触发也会暂停，因此不会打断你的转换过程。

## 它不做什么

- 不做云端推理。这里没有填 API key 的地方，因为根本没有要连的 API。
- 不做遥测、不做统计、不记录输入。
- 不需要账号、不需要订阅、没有用量上限。
- 它不改写、不翻译、不重组你的文字。它只是把你起的头写完。

## 系统要求

| | 最低 | 推荐 |
|--|------|------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **芯片** | Apple M1 | Apple M2 Pro 或更好 |
| **内存** | 8 GB | 16 GB 以上 |
| **存储** | 1 GB 加上模型体积 | 5 GB |

## 隐私

每一条补全都在你的 Mac 上生成。内置后端连接 `127.0.0.1` 上的 `llama-server` 进程；外部后端连接你自己配置的回环地址。除了检查自身更新，GhostType 不发起任何其他网络请求。

## 遇到问题时

**系统设置里开关是开着的，GhostType 却说没有权限。**
从 0.3.1 或更早版本升级上来的人都会遇到这个。macOS 把每一次辅助功能授权，绑定到接受授权的那个应用的代码签名上。0.3.1 之前的每个版本都用构建自身的哈希来签名，所以每换一个版本签名就变一次。1.0.0 改用固定的证书，到此为止，但你的 Mac 里仍然存着旧规则。拨动开关只会更新授权状态，不会重写附在上面的规则，于是开关看起来是开的，应用却一直被拒绝。

关掉再打开没用，用减号把 GhostType 从列表里移除也没用。必须删掉存下来的那条记录：

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

然后重新启动 GhostType，在它询问时授权。只需要做一次。想确认自己是不是这种情况，看下面的日志里有没有 `Failed to match existing code requirement`：

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**在其他应用里不出补全。**
看菜单栏状态。如果显示需要授予辅助功能或输入监控，就到系统设置里对应的面板把 GhostType 打开，它会在几秒内自动重启。从源码编译会重新签名；如果编译时没有指定签名身份，签名每次都会变，于是每编译一次 macOS 就要你重新授权一次辅助功能。执行一次 `scripts/make-signing-cert.sh`，之后带着 `GHOSTTYPE_SIGN_IDENTITY` 编译，权限就能跨重新编译保留。

**在设置里的测试框能用，别处不行。**
这正好是缺辅助功能权限。测试框在 GhostType 内部，不需要系统权限。

**状态显示 Ready，但不出灰字。**
确认模型已下载（内置）或服务器在运行（外部）。试试手动快捷键。再看看这个应用是不是在排除列表里。

**内置后端提示找不到 llama.cpp 的二进制文件。**
你运行的是没有包含它们的构建。执行 `scripts/fetch-llama.sh` 后重新编译，或者改用外部服务器。

## 从源码编译

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

首次编译时会自动获取锁定版本的 llama.cpp 二进制文件并放进应用包，所以没有单独的准备步骤。想手动获取，或者要为 Intel 编译：

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

其他脚本：

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

需要 Xcode 和命令行工具（`xcode-select --install`）。

## 结构

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

## 致谢

推理由 [llama.cpp](https://github.com/ggml-org/llama.cpp)（MIT）驱动。写作模型是 [mradermacher](https://huggingface.co/mradermacher) 转换的 Qwen3.5 Base GGUF，代码模型是 [ggml-org](https://huggingface.co/ggml-org) 转换的 [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder)。两个模型系列均为 Apache-2.0。

## 许可证

[MIT](../../LICENSE)。随便用、随便 fork、拿去做商业产品也可以。没有附加条件。

---

**GhostType** *Type less. Think more.*
