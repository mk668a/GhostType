<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · 한국어 · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md)

# GhostType

**Mac의 모든 텍스트 입력란에서 Tab 한 번으로 문장을 완성합니다. 전부 내 컴퓨터 안에서 돌아갑니다.**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="타이핑을 멈추면 커서 위치에 회색 글씨가 나타나고, Tab을 누르면 입력됩니다" width="760">
</p>

GhostType은 비공개 소스 Mac 자동완성 앱 [Cotypist](https://cotypist.app/)의 무료 대안이며 MIT 라이선스입니다.

## 이런 상황

Gmail에서 답장을 쓰는 중이고 이미 세 문장을 썼습니다. 이 문장이 어떻게 끝날지는 이미 머릿속에 있습니다. 그래도 끝까지 다 쳐야 합니다.

편집기는 이 문제를 오래전에 해결했습니다. GitHub Copilot은 남은 줄을 회색으로 보여주고, Tab을 누르면 됩니다. 그런데 메일, Slack, 메모, 그리고 하루의 대부분을 보내는 브라우저 입력란에는 그런 것이 없습니다.

## GhostType이 하는 일

타이핑을 멈춥니다. 커서 자리에 회색 글씨가 뜹니다. `Tab`을 누릅니다.

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

내장 모델이 실제로 내놓은 결과입니다. Safari, 메모, 메일, Slack을 비롯한 모든 macOS 텍스트 입력란에서 똑같이 동작합니다.

<p align="center">
  <img src="../../images/usecase1.png" alt="Gmail에서 사용하는 GhostType" width="600">
  <br>
  <em>Gmail에서 답장 쓰기</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="X에서 사용하는 GhostType" width="600">
  <br>
  <em>X에 글 쓰기</em>
</p>

## 두 가지 실행 방식

로컬 AI Mac 앱 대부분이 여기서 어긋납니다. 모델을 함께 넣어 배포하는데, 이미 서버를 돌리고 있는 사람은 같은 가중치를 메모리에 두 벌 올려두게 됩니다. GhostType은 직접 고르게 합니다.

| | 내장 | 외부 서버 |
|---|---|---|
| **준비** | 설정에서 모델을 내려받으면 끝. 따로 설치할 것이 없습니다. | 이미 돌리고 있는 서버 주소를 알려주면 됩니다. |
| **실행 주체** | 앱에 포함된 `llama-server` | LM Studio, Ollama, llama.cpp, vLLM, LocalAI |
| **메모리 위의 모델** | 한 벌, GhostType이 올립니다 | 추가 사용 없음. 이미 올라간 것을 그대로 씁니다. |
| **어울리는 경우** | "그냥 바로 쓰고 싶다." | "이미 32B 모델을 띄워 놨으니 그걸 쓰자." |

두 경로 모두 같은 OpenAI 호환 HTTP 엔드포인트에서 끝납니다. 서로 다른 제품 두 개를 붙여 놓은 것이 아니라, 서버 프로세스를 누가 관리하느냐만 다릅니다.

외부 서버가 마침 `llama-server`라면 GhostType이 자동으로 알아차리고, 내장 백엔드와 동일한 고품질 보완 경로를 씁니다. 그게 무슨 뜻인지는 [보완 품질](#보완-품질)에서 설명합니다.

## 설치

[Releases](https://github.com/mk668a/GhostType/releases) 페이지에서 최신 `.dmg`를 받아 열고, **GhostType**을 **응용 프로그램**으로 끌어다 놓습니다.

### 첫 실행 승인

GhostType은 공증(notarization)을 받지 않았습니다. 공증에는 유료 Apple Developer 계정이 필요한데 이 프로젝트에는 없습니다. 그래서 macOS가 첫 실행을 막고 직접 승인하라고 요구합니다. 한 번만 하면 됩니다.

1. **GhostType**을 엽니다. macOS가 개발자를 확인할 수 없다며 거부합니다.
2. **시스템 설정 > 개인정보 보호 및 보안**을 열고 **보안** 항목까지 내려갑니다.
3. GhostType이 차단되었다는 메시지 옆의 **그래도 열기**를 누르고, **열기**로 확인합니다.

> macOS 15 Sequoia 이후에서는 앱을 Control 클릭해서 **열기**를 고르는 방법이 통하지 않습니다. Apple이 그 단축 경로를 없앴기 때문에 시스템 설정이 유일한 길입니다.

이후 GhostType이 스스로 설치하는 업데이트에서는 이 과정이 반복되지 않습니다. 이 검사는 내려받은 앱의 첫 실행에만 적용되고, 제자리에서 갱신되는 앱에는 적용되지 않습니다.

이 과정을 아예 건너뛰려면 [직접 빌드](#소스에서-빌드하기)하세요. 직접 컴파일한 앱은 내려받은 적이 없으므로 격리 표시가 붙지 않고, 아무 경고 없이 실행됩니다.

## 설정

### 1단계: 백엔드 고르기

첫 실행 때 설정 안내가 열립니다. **내장**을 골라 모델을 내려받거나, **외부 서버**를 골라 주소를 입력합니다.

내장 모델입니다. 글쓰기용으로는 대화용으로 조정된 모델이 아니라 베이스 모델을 씁니다. 대화 모델에게 문장을 이어 달라고 하면 이어 쓰는 대신 대답을 해버리기 때문입니다.

| 모델 | 크기 | 용도 | 비고 |
|------|------|------|------|
| Qwen3.5 0.8B Base | 약 0.6 GB | 글쓰기 | 가장 빠름. 메모리 8 GB Mac에서도 충분합니다. |
| Qwen3.5 2B Base | 약 1.3 GB | 글쓰기 | 권장. 속도와 품질의 균형이 가장 좋습니다. |
| Qwen3.5 4B Base | 약 2.7 GB | 글쓰기 | 품질 우선. 메모리 16 GB 이상을 권합니다. |
| Qwen2.5-Coder 0.5B | 약 0.5 GB | 코드 | 가볍고, 코드와 기술 문서에 맞습니다. |
| Qwen2.5-Coder 1.5B | 약 1.6 GB | 코드 | 코드에 강하고 일상 문장에는 약합니다. |

모델은 `~/Library/Application Support/GhostType/models`에 저장되며 Mac 밖으로 나가지 않습니다.

### 2단계: 두 가지 권한 허용

둘 다 필요합니다.

- **입력 모니터링**: 타이핑이 멈춘 것을 알아차리는 데 씁니다
- **손쉬운 사용**: 커서 주변 텍스트를 읽고, 수락한 내용을 넣는 데 씁니다

**시스템 설정 > 개인정보 보호 및 보안**에서 각각 GhostType을 켭니다. 어느 쪽이 아직 빠졌는지는 메뉴 막대 아이콘이 알려줍니다.

### 3단계: 아무거나 쳐 보기

텍스트 편집기를 열고 문장을 절반쯤 쓴 뒤 잠깐 멈춥니다. 회색 글씨가 나타납니다. `Tab`을 누릅니다.

## 보완 품질

수락하는 보완과 지워버리는 보완을 가르는 것은 두 가지입니다.

**중간 채우기(fill-in-the-middle).** 대부분의 자동완성 도구는 커서 앞쪽 텍스트만 모델에 보냅니다. 모델은 뒤에 이미 문장이 이어진다는 사실을 모르므로, 이미 있는 결말 위에 또 하나의 결말을 씁니다. GhostType은 llama.cpp의 `/infill` 엔드포인트로 커서 양쪽 텍스트를 함께 보냅니다. 그래서 보완이 문장 **안쪽**에 들어가고, 꼬리를 중복해서 쓰지 않습니다.

**제약 생성.** 문장을 완성하라고 하면 모델이 코드 블록을 내놓거나, 방금 한 말을 따옴표로 되풀이하거나, 세 문단짜리 설명을 쓰기도 합니다. 나중에 정리하는 것은 결국 추측입니다. 대신 GhostType은 GBNF 문법을 컴파일해 샘플러에 넘겨, 그런 토큰을 애초에 고를 수 없게 만듭니다. 버려질 텍스트를 만드는 데 모델이 시간을 쓰지 않습니다.

| 설정 | 문법 | 이럴 때 |
|------|------|---------|
| 한 줄 | 줄바꿈과 앞머리 코드 블록을 막습니다 | 메일, 채팅, 브라우저 입력란 (기본값) |
| 몇 줄까지 | 최대 4줄까지 허용합니다 | 편집기, 메모, 여러 줄 입력란 |
| 제약 없음 | 없음 | 특정 모델이 제약 아래에서 이상하게 굴 때 |

두 기능 모두 llama.cpp의 API를 쓰는 서버가 필요합니다. 내장 백엔드는 항상 그렇고, 외부 `llama-server`도 마찬가지입니다. 일반 OpenAI 호환 서버가 상대라면 GhostType은 커서 표시를 넣은 chat completions로 물러섭니다. 동작은 하지만 눈에 띄게 무딥니다.

## 단축키

| 키 | 동작 |
|----|------|
| `Tab` | 보완 수락 |
| `Esc` | 보완 닫기 |
| `Cmd + Option + \` | 보완 수동 실행 |
| `Cmd + Shift + G` | GhostType 켜기/끄기 |

모든 단축키는 설정에서 바꿀 수 있습니다.

## 앱 호환성

| 앱 종류 | 자동 실행 | 이유 |
|---------|-----------|------|
| 텍스트 편집기, 메모, Pages | 지원 | 손쉬운 사용 API를 완전히 지원합니다 |
| Safari, Chrome의 웹 입력란 | 지원 | 키 입력 버퍼로 대체합니다 |
| 메일, Slack, Discord | 수동만 | 자동 실행이 앱 자체 입력 처리와 부딪힙니다 |
| IDE, 터미널 | 끔 | 이미 자체 자동완성이 있습니다 |

한국어, 일본어, 중국어처럼 ASCII가 아닌 입력기가 조합 중일 때도 자동 실행이 멈춥니다. 변환 도중에 끼어들지 않습니다.

## 하지 않는 것

- 클라우드 추론을 하지 않습니다. API 키를 넣는 칸이 없는데, 연결할 API 자체가 없기 때문입니다.
- 원격 측정, 분석, 입력 기록을 하지 않습니다.
- 계정도 구독도 사용량 제한도 없습니다.
- 글을 고쳐 쓰거나 번역하거나 재구성하지 않습니다. 시작한 문장을 끝맺을 뿐입니다.

## 시스템 요구사항

| | 최소 | 권장 |
|--|------|------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **칩** | Apple M1 | Apple M2 Pro 이상 |
| **메모리** | 8 GB | 16 GB 이상 |
| **저장 공간** | 1 GB + 모델 크기 | 5 GB |

## 개인정보

모든 보완은 당신의 Mac에서 만들어집니다. 내장 백엔드는 `127.0.0.1`의 `llama-server` 프로세스와 통신하고, 외부 백엔드는 직접 설정한 루프백 주소와 통신합니다. 자체 업데이트 확인을 빼면 GhostType은 어떤 네트워크 요청도 보내지 않습니다.

## 문제가 생기면

**시스템 설정에서는 켜져 있는데 GhostType은 권한이 없다고 합니다.**
0.3.1 이하에서 업데이트한 사람은 모두 여기에 걸립니다. macOS는 손쉬운 사용 권한을 그 권한을 받은 앱의 코드 서명에 묶어 저장합니다. 0.3.1까지의 모든 릴리스는 빌드 자체의 해시로 서명되어 버전마다 서명이 바뀌었습니다. 1.0.0부터는 고정된 인증서를 쓰므로 여기서 끝나지만, 당신의 Mac에는 옛 규칙이 그대로 남아 있습니다. 스위치를 켜고 끄는 것은 권한 값만 바꿀 뿐 거기에 붙은 규칙을 다시 쓰지 않습니다. 그래서 스위치는 켜져 보이는데 앱은 계속 거부당합니다.

껐다 켜도 지워지지 않고, 빼기 버튼으로 목록에서 GhostType을 지워도 마찬가지입니다. 저장된 항목 자체를 삭제해야 합니다.

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

그다음 GhostType을 다시 실행하고, 물어보면 승인하세요. 한 번이면 충분합니다. 자신이 이 경우인지 확인하려면 아래 로그에 `Failed to match existing code requirement`가 있는지 보세요.

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**다른 앱에서 보완이 나타나지 않습니다.**
메뉴 막대 상태를 보세요. 손쉬운 사용이나 입력 모니터링을 허용하라고 되어 있으면, 시스템 설정의 해당 패널에서 GhostType을 켭니다. 몇 초 안에 스스로 재시작합니다. 소스에서 빌드하면 앱이 다시 서명되는데, 서명 ID 없이 빌드하면 매번 서명이 바뀌므로 빌드할 때마다 손쉬운 사용을 다시 허용해야 합니다. `scripts/make-signing-cert.sh`를 한 번 실행하고 `GHOSTTYPE_SIGN_IDENTITY`를 설정해 빌드하면 다시 빌드해도 권한이 유지됩니다.

**설정 화면의 테스트 칸에서는 되는데 다른 곳에서는 안 됩니다.**
정확히 손쉬운 사용 권한 문제입니다. 테스트 칸은 GhostType 안에 있어서 시스템 권한이 필요 없습니다.

**상태는 Ready인데 회색 글씨가 안 나옵니다.**
모델을 내려받았는지(내장) 또는 서버가 돌고 있는지(외부) 확인하세요. 수동 단축키도 눌러 보고, 그 앱이 제외 목록에 있는지도 보세요.

**내장 백엔드가 llama.cpp 바이너리가 없다고 합니다.**
바이너리 없이 만든 빌드를 실행하고 있습니다. `scripts/fetch-llama.sh`를 실행한 뒤 다시 빌드하거나, 외부 서버로 바꾸세요.

## 소스에서 빌드하기

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

첫 빌드에서 고정된 버전의 llama.cpp 바이너리를 자동으로 받아 앱 번들에 넣습니다. 별도의 준비 단계가 없습니다. 직접 받거나 Intel용으로 빌드하려면:

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

다른 스크립트:

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

Xcode와 명령줄 도구(`xcode-select --install`)가 필요합니다.

## 구조

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

## 크레딧

추론은 [llama.cpp](https://github.com/ggml-org/llama.cpp)(MIT) 위에서 돌아갑니다. 글쓰기 모델은 [mradermacher](https://huggingface.co/mradermacher)가 변환한 Qwen3.5 Base GGUF이고, 코드 모델은 [ggml-org](https://huggingface.co/ggml-org)가 변환한 [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder)입니다. 두 모델 계열 모두 Apache-2.0입니다.

## 라이선스

[MIT](../../LICENSE). 쓰고, 포크하고, 상업적으로 배포해도 됩니다. 조건은 없습니다.

---

**GhostType** *Type less. Think more.*
