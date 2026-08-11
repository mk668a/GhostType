<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · 日本語

# GhostType

**Macのあらゆるテキスト欄で、Tabキーひとつで続きが書ける。しかも全部あなたのMacの中で動く。**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="打鍵を止めるとカーソル位置にグレーの補完が現れ、Tabで確定する" width="760">
</p>

GhostTypeは、クローズドソースのMac用補完アプリ[Cotypist](https://cotypist.app/)の、MITライセンスによる無料の代替です。

## こういう場面のために

Gmailで返信を3文ほど書いたところ。この文がどう終わるかは、もう頭の中にある。それでも全部打たないといけない。

エディタはこの問題を何年も前に解決しました。GitHub Copilotが行の続きをグレーで見せてくれて、Tabキーを押すだけ。ところがメールにもSlackにもメモにも、そして実際に一日の大半を費やしているブラウザの入力欄にも、それがありません。

## GhostTypeがすること

打つ手を止めると、カーソル位置にグレーの文字が出ます。`Tab`キーを押します。

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

これは同梱の0.5Bモデルが実際に返した補完です。Safari、メモ、メール、Slack、その他どのテキスト欄でも同じように動きます。

<p align="center">
  <img src="../../images/usecase1.png" alt="GhostType in Gmail" width="600">
  <br>
  <em>Gmailで返信を書く</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="GhostType on X" width="600">
  <br>
  <em>Xに投稿を書く</em>
</p>

## 動かし方は2通り

ローカルAI系のMacアプリの多くがここを外しています。モデルを同梱するので、すでに自分でモデルを動かしている人は、同じ重みがメモリ上に2つ載ることになる。GhostTypeは選ばせます。

| | 内蔵 | 外部サーバー |
|---|---|---|
| **準備** | 設定画面でモデルをダウンロードするだけ。他に入れるものなし。 | すでに動かしているサーバーを指定するだけ。 |
| **実体** | アプリに同梱した`llama-server` | LM Studio、Ollama、llama.cpp、vLLM、LocalAI |
| **メモリ上のモデル** | GhostTypeが読み込む1つ | 追加ゼロ。すでに載っているものを使う。 |
| **向いている人** | 「とにかく動いてほしい」 | 「32Bをもう動かしてるからそれを使え」 |

どちらも最終的には同じOpenAI互換のHTTPエンドポイントに行き着くので、2つの別物を貼り合わせたつくりにはなっていません。違うのはサーバープロセスを誰が持つかだけです。

外部サーバーが`llama-server`だった場合、GhostTypeはそれを自動で判別し、内蔵バックエンドと同じ高品質な補完経路を使います。詳しくは[補完の品質](#補完の品質)を参照してください。

## インストール

[Releases](https://github.com/mk668a/GhostType/releases)から最新の`.dmg`をダウンロードし、開いて**GhostType**を**アプリケーション**にドラッグします。

### 初回起動時の許可

GhostTypeはnotarize(Appleの公証)を受けていません。公証には有料のApple Developerアカウントが必要で、このプロジェクトは持っていないためです。そのためmacOSが初回起動をブロックし、手動での許可を求めます。1回だけの作業です。

1. **GhostType**を開く。macOSが「開発元を確認できません」と拒否します
2. **システム設定 > プライバシーとセキュリティ**を開き、下方の**セキュリティ**まで進む
3. GhostTypeがブロックされた旨のメッセージの横で**このまま開く**をクリックし、確認ダイアログで**開く**

> macOS 15 Sequoia以降では、アプリを右クリックして**開く**を選ぶ方法は使えません。Appleがこのショートカットを削除したため、システム設定からの許可が唯一の経路です。

GhostType自身が後から適用するアップデートでは、この手順は繰り返されません。この確認はダウンロードしたアプリの初回起動にだけ適用され、その場で更新されるアプリには適用されないためです。

この手順を丸ごと省きたい場合は[自分でビルド](#ソースからビルドする)してください。自分でコンパイルしたアプリはダウンロードされたものではないので隔離フラグが付かず、警告なしで起動します。

## セットアップ

### 手順1: バックエンドを選ぶ

初回起動時にセットアップガイドが開きます。**内蔵**を選んでモデルをダウンロードするか、**外部サーバー**を選んでエンドポイントを入力します。

内蔵モデル:

| モデル | サイズ | 備考 |
|--------|--------|------|
| Qwen2.5-Coder 0.5B | 約0.5GB | 最速。メモリ8GBのMacでも快適。 |
| Qwen2.5-Coder 1.5B | 約1.6GB | 推奨。速度と品質のバランスが最良。 |
| Qwen2.5-Coder 3B | 約3.1GB | 品質重視。メモリ16GB以上向け。 |

モデルは`~/Library/Application Support/GhostType/models`に保存され、Macの外に出ることはありません。

### 手順2: 2つの権限を許可する

GhostTypeには両方が必要です。

- **入力監視**: 打鍵が止まったことを検知するため
- **アクセシビリティ**: カーソル周辺の文章を読み、確定した補完を挿入するため

**システム設定 > プライバシーとセキュリティ**でそれぞれ有効にします。どちらが足りていないかはメニューバーのアイコンが教えてくれます。

### 手順3: 何か打ってみる

テキストエディットを開いて文を半分だけ書き、少し待ちます。グレーの文字が出たら`Tab`キーです。

## 補完の品質

採用したくなる補完と、消したくなる補完を分けるのは、次の2点です。

**Fill-in-the-middle(前後を見た補完)。** 多くの補完ツールはカーソルより前の文章しかモデルに渡しません。モデルは文の続きがすでに存在することを知らないまま書くので、すでにある結びの上にもう一つ結びを書いてしまいます。GhostTypeはllama.cppの`/infill`エンドポイントを使って前後両方を渡すため、補完が文の末尾を重複させず、文の「中」に収まります。

**制約付き生成。** 文の続きを頼まれたモデルは、ときどきコードフェンスで囲んだり、元の文を引用し直したり、3段落の解説を書いたりします。それを後から取り除くのは当て推量です。GhostTypeはGBNF文法を組み立ててサンプラーに渡し、そうしたトークンをそもそも選べなくします。捨てる前提の文章を生成する時間自体が発生しません。

| 設定 | 文法 | 使いどころ |
|------|------|-----------|
| 1行 | 改行と行頭のコードフェンスを禁止 | メール、チャット、ブラウザの入力欄(既定) |
| 数行まで | 最大4行まで許可 | エディタ、メモ、複数行の入力欄 |
| 制約なし | なし | 制約下でモデルの挙動がおかしいとき |

どちらの機能もllama.cppのAPIを話すサーバーが前提です。内蔵バックエンドでは常に成立し、外部の`llama-server`でも成立します。それ以外のOpenAI互換サーバーに対しては、カーソル位置を印で示すチャット補完に切り替わります。動きはしますが、切れ味は明らかに落ちます。

## キーボードショートカット

| キー | 動作 |
|------|------|
| `Tab` | 補完を確定 |
| `Esc` | 補完を消す |
| `Cmd + Option + \` | 手動で補完を呼ぶ |
| `Cmd + Shift + G` | GhostTypeのオン/オフ |

すべて設定画面で変更できます。

## アプリごとの対応状況

| アプリの種類 | 自動補完 | 理由 |
|--------------|----------|------|
| テキストエディット、メモ、Pages | 対応 | アクセシビリティAPIに完全対応 |
| Safari、Chromeの入力欄 | 対応 | 打鍵バッファで代替 |
| メール、Slack、Discord | 手動のみ | 自動補完がアプリ側の入力処理と競合する |
| IDE、ターミナル | 無効 | 元から補完機能がある |

日本語、中国語、韓国語などの入力メソッドが変換中のあいだは自動補完が止まるので、変換の邪魔をすることはありません。

## やらないこと

- クラウド推論をしません。APIキーの入力欄がないのは、キーを入れる先のAPIが存在しないからです。
- テレメトリも解析も入力ログも取りません。
- アカウント登録も、サブスクリプションも、利用回数の上限もありません。
- 文章の書き換え、翻訳、再構成はしません。書き始めた文を最後まで書くだけです。

## 動作環境

| | 最低 | 推奨 |
|--|------|------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **チップ** | Apple M1 | Apple M2 Pro以上 |
| **メモリ** | 8GB | 16GB以上 |
| **ストレージ** | 1GB+モデル分 | 5GB |

## プライバシー

補完はすべてMacの中で生成されます。内蔵バックエンドは`127.0.0.1`上の`llama-server`プロセスと通信し、外部バックエンドは指定したループバックアドレスと通信します。GhostType自身のアップデート確認以外に、ネットワーク通信は発生しません。

## うまく動かないとき

**他のアプリで補完が出ない。**
メニューバーの状態を見てください。「アクセシビリティを許可」または「入力監視を許可」と出ていたら、システム設定の該当ペインでGhostTypeをオンにします。数秒で自動的に再起動します。ソースからビルドするとコード署名が変わるので、ビルドのたびにアクセシビリティの再許可を求められます。

**設定画面のテスト欄では出るのに、他では出ない。**
アクセシビリティ権限だけが足りていません。テスト欄はGhostType自身の中にあるため、システム権限を必要としません。

**状態は「Ready」なのにグレーの文字が出ない。**
内蔵ならモデルがダウンロード済みか、外部ならサーバーが動いているかを確認してください。手動ショートカットも試し、除外アプリ一覧に入っていないかも見てください。

**内蔵バックエンドが「llama.cppのバイナリがない」と言う。**
バイナリを含めずにビルドされたものを動かしています。`scripts/fetch-llama.sh`を実行して再ビルドするか、外部サーバーに切り替えてください。

## ソースからビルドする

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

ビルドは初回にllama.cppの固定バージョンのリリースバイナリを取得し、アプリバンドルに配置します。別途の準備は不要です。手動で取得する場合や、Intel向けにビルドする場合は次のとおりです。

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

その他のスクリプト:

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

Xcodeとコマンドラインツール(`xcode-select --install`)が必要です。

## 構成

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

## クレジット

推論は[llama.cpp](https://github.com/ggml-org/llama.cpp)(MIT)で動いています。同梱モデルは[Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder)(Apache-2.0)を[ggml-org](https://huggingface.co/ggml-org)がGGUFに変換したものです。

## ライセンス

[MIT](../../LICENSE)。使うのも、フォークするのも、商用で売るのも自由です。

---

**GhostType** *Type less. Think more.*
