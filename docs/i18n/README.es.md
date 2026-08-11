<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [한국어](README.ko.md) · Español · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md)

# GhostType

**Autocompletado con Tab en todos los campos de texto de tu Mac, funcionando por completo en tu propio equipo.**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="Al pausar la escritura aparece texto gris en el cursor y Tab lo acepta" width="760">
</p>

GhostType es una alternativa gratuita y con licencia MIT a [Cotypist](https://cotypist.app/), la aplicación de autocompletado para Mac de código cerrado.

## La situación

Llevas tres frases escritas en una respuesta de Gmail. Ya sabes cómo termina la frase. Aun así tienes que escribirla entera.

Tu editor resolvió esto hace años: GitHub Copilot te muestra en gris el resto de la línea y pulsas Tab. Nada hace eso por Mail, Slack, Notas ni por el campo de texto del navegador donde realmente pasas el día.

## Qué hace GhostType

Dejas de escribir. Aparece texto gris en el cursor. Pulsas `Tab`.

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

Es una sugerencia real de uno de los modelos incluidos. Funciona igual en Safari, Notas, Mail, Slack y cualquier otro campo de texto de macOS.

<p align="center">
  <img src="../../images/usecase1.png" alt="GhostType en Gmail" width="600">
  <br>
  <em>Redactando una respuesta en Gmail</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="GhostType en X" width="600">
  <br>
  <em>Escribiendo una publicación en X</em>
</p>

## Dos formas de ejecutarlo

Aquí es donde fallan casi todas las aplicaciones de IA local para Mac. Incluyen un modelo y, si ya tenías uno en marcha, acabas con dos copias de los mismos pesos ocupando memoria. GhostType te deja elegir.

| | Integrado | Servidor externo |
|---|---|---|
| **Preparación** | Descarga un modelo desde Ajustes. Nada más que instalar. | Apunta GhostType al servidor que ya tienes. |
| **Qué ejecuta** | `llama-server`, incluido dentro de la aplicación | LM Studio, Ollama, llama.cpp, vLLM, LocalAI |
| **Modelo en memoria** | Una copia, cargada por GhostType | Ninguna copia extra. Reutiliza lo que ya está cargado. |
| **Ideal para** | «Solo quiero que funcione.» | «Ya tengo un modelo de 32B corriendo, usa ese.» |

Ambos caminos terminan en el mismo endpoint HTTP compatible con OpenAI, así que no son dos productos distintos pegados con cinta. La única diferencia es quién gestiona el proceso del servidor.

Si tu servidor externo resulta ser `llama-server`, GhostType lo detecta solo y usa la misma ruta de sugerencias de alta calidad que el motor integrado. En [Calidad de las sugerencias](#calidad-de-las-sugerencias) se explica qué significa eso.

## Instalación

Descarga el `.dmg` más reciente desde la página de [Releases](https://github.com/mk668a/GhostType/releases), ábrelo y arrastra **GhostType** a **Aplicaciones**.

### Aprobarlo en el primer arranque

GhostType no está notarizado. La notarización exige una cuenta de pago de Apple Developer, que este proyecto no tiene, así que macOS bloquea el primer arranque y te pide aprobarlo a mano. Es un paso único.

1. Abre **GhostType**. macOS se niega y dice que no puede verificar al desarrollador.
2. Abre **Ajustes del Sistema > Privacidad y seguridad** y baja hasta **Seguridad**.
3. Junto al mensaje que dice que GhostType fue bloqueado, pulsa **Abrir igualmente** y luego **Abrir** para confirmar.

> En macOS 15 Sequoia y posteriores, hacer clic con la tecla Control y elegir **Abrir** ya no funciona. Apple retiró ese atajo, así que Ajustes del Sistema es la única vía.

Las actualizaciones que GhostType instala por su cuenta no repiten esto. La comprobación se aplica al primer arranque de una aplicación descargada, no a una que se actualiza en su sitio.

Para saltarte todo esto, [compílalo tú mismo](#compilar-desde-el-código-fuente). Una aplicación compilada por ti nunca se descargó, así que no lleva marca de cuarentena y arranca sin ningún aviso.

## Configuración

### Paso 1: elige un motor

La guía de configuración se abre en el primer arranque. Elige **Integrado** y descarga un modelo, o elige **Servidor externo** e introduce su dirección.

Modelos integrados. Para prosa se usan modelos base y no modelos ajustados para conversación, porque a un modelo de chat le pides que termine una frase y tiende a responderte en lugar de continuarla:

| Modelo | Tamaño | Para | Notas |
|--------|--------|------|-------|
| Qwen3.5 0.8B Base | ~0,6 GB | Prosa | El más rápido. Va bien en Macs de 8 GB. |
| Qwen3.5 2B Base | ~1,3 GB | Prosa | Recomendado. Mejor equilibrio entre latencia y calidad. |
| Qwen3.5 4B Base | ~2,7 GB | Prosa | Máxima calidad. Pide 16 GB o más. |
| Qwen2.5-Coder 0.5B | ~0,5 GB | Código | Ligero, para código y escritura técnica. |
| Qwen2.5-Coder 1.5B | ~1,6 GB | Código | Mejor en código, más flojo en prosa cotidiana. |

Los modelos se descargan en `~/Library/Application Support/GhostType/models` y nunca salen de tu Mac.

### Paso 2: concede dos permisos

GhostType necesita los dos:

- **Monitorización de entrada** para notar que has dejado de escribir
- **Accesibilidad** para leer el texto alrededor del cursor e insertar lo que aceptas

Activa GhostType en **Ajustes del Sistema > Privacidad y seguridad** para cada uno. El icono de la barra de menús te dice cuál falta todavía.

### Paso 3: escribe algo

Abre TextEdit, escribe media frase y espera. Aparece texto gris. Pulsa `Tab`.

## Calidad de las sugerencias

Dos cosas marcan la diferencia entre una sugerencia que aceptas y otra que borras.

**Relleno intermedio (fill-in-the-middle).** La mayoría de herramientas de autocompletado envían al modelo solo el texto anterior al cursor. Ese modelo no tiene forma de saber que la frase ya continúa después de ti, así que escribe un segundo final encima del que ya tienes. GhostType envía el texto de ambos lados usando el endpoint `/infill` de llama.cpp, de modo que la sugerencia cae **dentro** de tu frase en lugar de duplicar su cola.

**Generación restringida.** A un modelo al que le pides terminar una frase a veces te responde con un bloque de código, con una repetición entrecomillada o con tres párrafos de explicación. Limpiar eso después es adivinar. En su lugar, GhostType compila una gramática GBNF y se la entrega al muestreador, que vuelve inalcanzables esos tokens desde el principio. El modelo no gasta tiempo generando texto que iba a acabar en la basura.

| Ajuste | Gramática | Cuándo usarlo |
|--------|-----------|---------------|
| Una línea | Bloquea saltos de línea y bloques de código iniciales | Correo, chat, campos del navegador (predeterminado) |
| Hasta unas líneas | Permite hasta 4 líneas | Editores, notas, campos multilínea |
| Sin restricción | Ninguna | Un modelo se comporta mal bajo restricciones |

Ambas funciones necesitan un servidor que hable la API de llama.cpp. Eso siempre se cumple con el motor integrado y también con un `llama-server` externo. Frente a un servidor compatible con OpenAI a secas, GhostType recurre a chat completions con un marcador de cursor, que sigue funcionando pero es visiblemente más tosco.

## Atajos de teclado

| Tecla | Acción |
|-------|--------|
| `Tab` | Aceptar la sugerencia |
| `Esc` | Descartar la sugerencia |
| `Cmd + Option + \` | Pedir una sugerencia manualmente |
| `Cmd + Shift + G` | Activar o desactivar GhostType |

Todos los atajos se pueden personalizar en Ajustes.

## Compatibilidad con aplicaciones

| Tipo de aplicación | Activación automática | Por qué |
|--------------------|-----------------------|---------|
| TextEdit, Notas, Pages | Sí | Soporte completo de la API de Accesibilidad |
| Campos web de Safari y Chrome | Sí | Recurre al búfer de pulsaciones |
| Mail, Slack, Discord | Solo manual | La activación automática choca con su propio manejo de entrada |
| IDEs, terminales | Desactivada | Ya tienen autocompletado propio |

La activación automática también se detiene mientras un método de entrada no ASCII (japonés, chino, coreano) está componiendo, así que nunca interfiere a mitad de conversión.

## Lo que no hace

- Nada de inferencia en la nube. No hay campo para una clave de API porque no hay ninguna API a la que conectarse.
- Sin telemetría, sin analíticas, sin registro de lo que escribes.
- Sin cuenta, sin suscripción, sin límite de uso.
- No reescribe, ni traduce, ni reestructura tu texto. Termina la frase que empezaste.

## Requisitos del sistema

| | Mínimo | Recomendado |
|--|--------|-------------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **Chip** | Apple M1 | Apple M2 Pro o superior |
| **Memoria** | 8 GB | 16 GB o más |
| **Almacenamiento** | 1 GB más el modelo | 5 GB |

## Privacidad

Cada sugerencia se genera en tu Mac. El motor integrado habla con un proceso `llama-server` en `127.0.0.1`; el motor externo habla con la dirección de bucle local que hayas configurado. GhostType no hace ninguna otra petición de red salvo comprobar sus propias actualizaciones.

## Solución de problemas

**El interruptor está activado en Ajustes del Sistema, pero GhostType dice que falta el permiso.**
Esto le pasa a todo el que actualiza desde la 0.3.1 o anterior. macOS vincula cada permiso de Accesibilidad a la firma de código de la aplicación que lo recibió, y todas las versiones hasta la 0.3.1 se firmaban con un hash de la propia compilación, que cambiaba en cada versión. La 1.0.0 usa un certificado estable, así que esto termina aquí, pero tu Mac todavía guarda la regla antigua. Mover el interruptor actualiza el permiso sin reescribir la regla asociada, así que la aplicación sigue siendo denegada mientras el interruptor se ve activado.

Apagar y encender el interruptor no lo arregla, y quitar GhostType de la lista con el botón menos tampoco. Hay que borrar la entrada guardada:

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

Después vuelve a abrir GhostType y apruébalo cuando lo pida. Con una vez basta. Para confirmar en qué caso estás, busca `Failed to match existing code requirement` aquí:

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**No aparecen sugerencias en otras aplicaciones.**
Mira el estado en la barra de menús. Si dice que hace falta conceder Accesibilidad o Monitorización de entrada, abre el panel correspondiente en Ajustes del Sistema y activa GhostType. Se reinicia solo en unos segundos. Compilar desde el código fuente vuelve a firmar la aplicación y, si compilas sin una identidad de firma, la firma cambia cada vez, así que macOS te pedirá Accesibilidad tras cada compilación. Ejecuta `scripts/make-signing-cert.sh` una vez y compila con `GHOSTTYPE_SIGN_IDENTITY` definido para conservar el permiso entre compilaciones.

**Funciona en el campo de prueba de Ajustes pero en ningún otro sitio.**
Eso es exactamente el permiso de Accesibilidad. El campo de prueba está dentro de GhostType, así que no necesita permisos del sistema.

**El estado dice «Ready» pero no aparece texto gris.**
Comprueba que hay un modelo descargado (integrado) o que el servidor está en marcha (externo). Prueba el atajo manual. Mira si la aplicación está en la lista de excluidas.

**El motor integrado dice que faltan los binarios de llama.cpp.**
Estás ejecutando una compilación hecha sin ellos. Ejecuta `scripts/fetch-llama.sh` y vuelve a compilar, o cambia a un servidor externo.

## Compilar desde el código fuente

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

La compilación descarga los binarios fijados de llama.cpp en su primera ejecución y los coloca dentro del paquete de la aplicación, así que no hay un paso de preparación aparte. Para descargarlos a mano, o para compilar para Intel:

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

Otros scripts:

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

Requiere Xcode y las Command Line Tools (`xcode-select --install`).

## Arquitectura

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

La inferencia funciona sobre [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT). Los modelos de prosa son conversiones GGUF de Qwen3.5 Base hechas por [mradermacher](https://huggingface.co/mradermacher), y los de código son las conversiones de [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder) hechas por [ggml-org](https://huggingface.co/ggml-org). Ambas familias de modelos son Apache-2.0.

## Licencia

[MIT](../../LICENSE). Úsalo, bifúrcalo, véndelo. Sin condiciones.

---

**GhostType** *Type less. Think more.*
