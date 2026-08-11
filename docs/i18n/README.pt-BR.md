<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · Português

# GhostType

**Autocompletar com Tab em todo campo de texto do seu Mac, rodando inteiramente na sua própria máquina.**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="A digitação para, um texto cinza aparece no cursor e o Tab aceita" width="760">
</p>

GhostType é uma alternativa gratuita e sob licença MIT ao [Cotypist](https://cotypist.app/), o aplicativo de autocompletar para Mac de código fechado.

## A situação

Você está na terceira frase de uma resposta no Gmail. Já sabe como a frase termina. Ainda assim precisa digitar tudo.

Seu editor resolveu isso anos atrás: o GitHub Copilot mostra o resto da linha em cinza e você aperta Tab. Nada faz isso pelo Mail, pelo Slack, pelas Notas, nem pelo campo de texto do navegador onde você de fato passa o dia.

## O que o GhostType faz

Você para de digitar. Um texto cinza aparece no cursor. Você aperta `Tab`.

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

Essa é uma sugestão real de um dos modelos incluídos. Funciona igual no Safari, nas Notas, no Mail, no Slack e em qualquer outro campo de texto do macOS.

<p align="center">
  <img src="../../images/usecase1.png" alt="GhostType no Gmail" width="600">
  <br>
  <em>Escrevendo uma resposta no Gmail</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="GhostType no X" width="600">
  <br>
  <em>Escrevendo um post no X</em>
</p>

## Duas formas de rodar

É aqui que a maioria dos aplicativos de IA local para Mac erra. Eles embutem um modelo e, se você já roda um, passa a ter duas cópias dos mesmos pesos ocupando memória. O GhostType deixa você escolher.

| | Integrado | Servidor externo |
|---|---|---|
| **Preparo** | Baixe um modelo nos Ajustes. Nada mais para instalar. | Aponte o GhostType para um servidor que você já mantém. |
| **O que roda** | `llama-server`, embutido no aplicativo | LM Studio, Ollama, llama.cpp, vLLM, LocalAI |
| **Modelo na memória** | Uma cópia, carregada pelo GhostType | Nenhuma a mais. Reaproveita o que já está carregado. |
| **Indicado para** | "Só quero que funcione." | "Já tenho um modelo de 32B rodando, use aquele." |

Os dois caminhos terminam no mesmo endpoint HTTP compatível com OpenAI, então não são dois produtos diferentes emendados. A única diferença é quem cuida do processo do servidor.

Se o seu servidor externo por acaso for o `llama-server`, o GhostType percebe sozinho e usa o mesmo caminho de sugestão de alta qualidade do backend integrado. O que isso significa está em [Qualidade das sugestões](#qualidade-das-sugestões).

## Instalação

Baixe o `.dmg` mais recente na página de [Releases](https://github.com/mk668a/GhostType/releases), abra e arraste o **GhostType** para **Aplicativos**.

### Liberando na primeira abertura

O GhostType não passou pela notarização da Apple. Notarizar exige uma conta paga do Apple Developer, que este projeto não tem, então o macOS bloqueia a primeira abertura e pede que você libere na mão. É uma etapa única.

1. Abra o **GhostType**. O macOS recusa, dizendo que não consegue verificar o desenvolvedor.
2. Abra **Ajustes do Sistema > Privacidade e Segurança** e role até **Segurança**.
3. Ao lado da mensagem sobre o GhostType ter sido bloqueado, clique em **Abrir Assim Mesmo** e confirme em **Abrir**.

> No macOS 15 Sequoia e posteriores, clicar no aplicativo com a tecla Control e escolher **Abrir** não funciona mais. A Apple removeu esse atalho, e os Ajustes do Sistema são o único caminho.

As atualizações que o GhostType instala sozinho depois não repetem isso. A verificação vale para a primeira abertura de um aplicativo baixado, não para um que se atualiza no lugar.

Para pular tudo isso, [compile você mesmo](#compilar-a-partir-do-código-fonte). Um aplicativo que você compilou nunca foi baixado, portanto não carrega marca de quarentena e abre sem aviso nenhum.

## Configuração

### Passo 1: escolha um backend

O guia de configuração abre na primeira execução. Escolha **Integrado** e baixe um modelo, ou escolha **Servidor externo** e informe o endereço.

Modelos integrados. Para texto corrido são modelos base, não modelos ajustados para conversa: peça a um modelo de chat para terminar uma frase e ele tende a respondê-la em vez de continuá-la.

| Modelo | Tamanho | Para | Observações |
|--------|---------|------|-------------|
| Qwen3.5 0.8B Base | ~0,6 GB | Texto | O mais rápido. Vai bem em Macs de 8 GB. |
| Qwen3.5 2B Base | ~1,3 GB | Texto | Recomendado. Melhor equilíbrio entre latência e qualidade. |
| Qwen3.5 4B Base | ~2,7 GB | Texto | Qualidade máxima. Pede 16 GB ou mais. |
| Qwen2.5-Coder 0.5B | ~0,5 GB | Código | Leve, para código e escrita técnica. |
| Qwen2.5-Coder 1.5B | ~1,6 GB | Código | Mais forte em código, mais fraco em texto do dia a dia. |

Os modelos são baixados em `~/Library/Application Support/GhostType/models` e nunca saem do seu Mac.

### Passo 2: conceda duas permissões

O GhostType precisa das duas:

- **Monitoramento de Entrada** para perceber que você parou de digitar
- **Acessibilidade** para ler o texto ao redor do cursor e inserir o que você aceita

Ative o GhostType em **Ajustes do Sistema > Privacidade e Segurança** para cada uma. O ícone na barra de menus diz qual ainda falta.

### Passo 3: digite alguma coisa

Abra o TextEdit, escreva meia frase e espere. O texto cinza aparece. Aperte `Tab`.

## Qualidade das sugestões

Duas coisas separam uma sugestão que você aceita de uma que você apaga.

**Preenchimento no meio (fill-in-the-middle).** A maioria das ferramentas de autocompletar manda ao modelo só o texto anterior ao cursor. Esse modelo não tem como saber que a frase já continua depois de você, então escreve um segundo final por cima do que existe. O GhostType manda o texto dos dois lados pelo endpoint `/infill` do llama.cpp, de modo que a sugestão cai **dentro** da sua frase em vez de duplicar o final dela.

**Geração restrita.** Um modelo encarregado de completar uma frase às vezes responde com um bloco de código, com uma repetição entre aspas ou com três parágrafos de explicação. Limpar isso depois é chute. Em vez disso, o GhostType compila uma gramática GBNF e a entrega ao amostrador, o que torna esses tokens inalcançáveis desde o início. O modelo não gasta tempo gerando texto que seria jogado fora.

| Ajuste | Gramática | Use quando |
|--------|-----------|------------|
| Uma linha | Bloqueia quebras de linha e blocos de código iniciais | E-mail, chat, campos do navegador (padrão) |
| Até algumas linhas | Permite até 4 linhas | Editores, notas, campos de várias linhas |
| Sem restrição | Nenhuma | Algum modelo se comporta mal sob restrição |

Os dois recursos exigem um servidor que fale a API do llama.cpp. Isso é sempre verdade no backend integrado, e também num `llama-server` externo. Diante de um servidor apenas compatível com OpenAI, o GhostType recorre a chat completions com um marcador de cursor, o que ainda funciona, mas é visivelmente mais tosco.

## Atalhos de teclado

| Tecla | Ação |
|-------|------|
| `Tab` | Aceitar a sugestão |
| `Esc` | Dispensar a sugestão |
| `Cmd + Option + \` | Pedir uma sugestão manualmente |
| `Cmd + Shift + G` | Ligar e desligar o GhostType |

Todos os atalhos podem ser trocados nos Ajustes.

## Compatibilidade com aplicativos

| Tipo de aplicativo | Disparo automático | Motivo |
|--------------------|--------------------|--------|
| TextEdit, Notas, Pages | Sim | Suporte completo à API de Acessibilidade |
| Campos web do Safari e do Chrome | Sim | Recorre ao buffer de teclas |
| Mail, Slack, Discord | Só manual | O disparo automático briga com o tratamento de entrada deles |
| IDEs, terminais | Desligado | Já têm autocompletar próprio |

O disparo automático também pausa enquanto um método de entrada fora do ASCII (japonês, chinês, coreano) está compondo, para nunca atrapalhar no meio da conversão.

## O que ele não faz

- Nada de inferência na nuvem. Não existe campo para chave de API, porque não existe API para se conectar.
- Sem telemetria, sem analytics, sem registro do que você digita.
- Sem conta, sem assinatura, sem limite de uso.
- Ele não reescreve, não traduz e não reorganiza seu texto. Ele termina a frase que você começou.

## Requisitos de sistema

| | Mínimo | Recomendado |
|--|--------|-------------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **Chip** | Apple M1 | Apple M2 Pro ou melhor |
| **Memória** | 8 GB | 16 GB ou mais |
| **Armazenamento** | 1 GB mais o modelo | 5 GB |

## Privacidade

Toda sugestão é gerada no seu Mac. O backend integrado conversa com um processo `llama-server` em `127.0.0.1`; o externo conversa com o endereço de loopback que você configurou. Fora a checagem das próprias atualizações, o GhostType não faz nenhuma outra requisição de rede.

## Resolução de problemas

**A chave está ligada nos Ajustes do Sistema, mas o GhostType diz que falta a permissão.**
Isso atinge todo mundo que atualiza da 0.3.1 ou anterior. O macOS amarra cada permissão de Acessibilidade à assinatura de código do aplicativo que a recebeu, e todas as versões até a 0.3.1 eram assinadas com um hash da própria compilação, que mudava a cada versão. A 1.0.0 usa um certificado estável, então isso acaba aqui, mas o seu Mac ainda guarda a regra antiga. Mexer na chave atualiza a permissão sem reescrever a regra presa a ela, e por isso o aplicativo continua sendo negado enquanto a chave aparece ligada.

Desligar e ligar de novo não resolve, e tirar o GhostType da lista com o botão de menos também não. É preciso apagar o registro guardado:

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

Depois abra o GhostType de novo e autorize quando ele pedir. Uma vez basta. Para confirmar se é o seu caso, procure por `Failed to match existing code requirement` aqui:

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**Não aparecem sugestões em outros aplicativos.**
Veja o status na barra de menus. Se disser que falta conceder Acessibilidade ou Monitoramento de Entrada, abra o painel correspondente nos Ajustes do Sistema e ative o GhostType. Ele se reinicia sozinho em alguns segundos. Compilar a partir do código-fonte assina o aplicativo de novo e, se você compilar sem uma identidade de assinatura, a assinatura muda toda vez, então o macOS pede Acessibilidade após cada compilação. Rode `scripts/make-signing-cert.sh` uma vez e compile com `GHOSTTYPE_SIGN_IDENTITY` definido para manter a permissão entre compilações.

**Funciona no campo de teste dos Ajustes, mas em nenhum outro lugar.**
Isso é exatamente a permissão de Acessibilidade. O campo de teste fica dentro do GhostType, então não precisa de permissão do sistema.

**O status diz "Ready", mas nenhum texto cinza aparece.**
Confirme que há um modelo baixado (integrado) ou que o servidor está rodando (externo). Tente o atalho manual. Veja se o aplicativo está na lista de excluídos.

**O backend integrado diz que faltam os binários do llama.cpp.**
Você está rodando uma compilação feita sem eles. Rode `scripts/fetch-llama.sh` e recompile, ou mude para um servidor externo.

## Compilar a partir do código-fonte

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

Na primeira execução, a compilação busca os binários fixados do llama.cpp e os coloca dentro do pacote do aplicativo, então não há uma etapa de preparo separada. Para buscá-los na mão, ou para compilar para Intel:

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

Outros scripts:

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

Requer o Xcode e as Command Line Tools (`xcode-select --install`).

## Arquitetura

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

## Créditos

A inferência roda sobre o [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT). Os modelos de texto são conversões GGUF do Qwen3.5 Base feitas pelo [mradermacher](https://huggingface.co/mradermacher), e os de código são as conversões do [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder) feitas pelo [ggml-org](https://huggingface.co/ggml-org). As duas famílias de modelos são Apache-2.0.

## Licença

[MIT](../../LICENSE). Use, faça fork, venda. Sem contrapartida.

---

**GhostType** *Type less. Think more.*
