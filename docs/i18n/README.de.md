<p align="center">
  <img src="../../images/header.png" alt="GhostType" width="600">
</p>

[English](../../README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · Deutsch · [Português](README.pt-BR.md)

# GhostType

**Tab-Autovervollständigung in jedem Textfeld deines Macs, vollständig auf deinem eigenen Rechner.**

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-brightgreen" alt="100% Local">
</p>

<p align="center">
  <img src="../../images/demo.gif" alt="Beim Innehalten erscheint grauer Text an der Einfügemarke, Tab übernimmt ihn" width="760">
</p>

GhostType ist eine kostenlose, MIT-lizenzierte Alternative zu [Cotypist](https://cotypist.app/), der Mac-App für Autovervollständigung mit geschlossenem Quellcode.

## Die Situation

Du bist bei der dritten Zeile einer Antwort in Gmail. Du weißt bereits, wie der Satz endet. Tippen musst du ihn trotzdem komplett.

Dein Editor hat das vor Jahren gelöst: GitHub Copilot zeigt dir den Rest der Zeile in Grau, und du drückst Tab. Für Mail, Slack, Notizen oder das Browser-Textfeld, in dem du deinen Tag tatsächlich verbringst, macht das nichts.

## Was GhostType tut

Du hörst auf zu tippen. An der Einfügemarke erscheint grauer Text. Du drückst `Tab`.

```
Before:  Thanks for sending over the draft. I read through it this morning and I think▌

After:   Thanks for sending over the draft. I read through it this morning and I think
         it's great. I'm going to start working on it today.▌
                    └─ grey ghost text, Tab to accept, Esc to dismiss
```

Das ist ein echter Vorschlag eines der mitgelieferten Modelle. In Safari, Notizen, Mail, Slack und jedem anderen macOS-Textfeld funktioniert es genauso.

<p align="center">
  <img src="../../images/usecase1.png" alt="GhostType in Gmail" width="600">
  <br>
  <em>Eine Antwort in Gmail verfassen</em>
</p>

<p align="center">
  <img src="../../images/usecase2.png" alt="GhostType auf X" width="600">
  <br>
  <em>Einen Beitrag auf X schreiben</em>
</p>

## Zwei Betriebsarten

Genau hier liegt der Fehler der meisten lokalen KI-Apps für den Mac. Sie bringen ein Modell mit, und wenn du ohnehin schon eines betreibst, liegen plötzlich zwei Kopien derselben Gewichte im Speicher. GhostType lässt dich wählen.

| | Eingebaut | Externer Server |
|---|---|---|
| **Einrichtung** | Modell in den Einstellungen laden. Sonst nichts zu installieren. | GhostType auf einen Server richten, den du schon betreibst. |
| **Was läuft** | `llama-server`, in der App enthalten | LM Studio, Ollama, llama.cpp, vLLM, LocalAI |
| **Modell im Speicher** | Eine Kopie, von GhostType geladen | Keine zusätzliche. Nutzt weiter, was schon geladen ist. |
| **Passend für** | „Es soll einfach laufen." | „Ich habe schon ein 32B-Modell laufen, nimm das." |

Beide Wege enden am selben OpenAI-kompatiblen HTTP-Endpunkt. Das sind also nicht zwei aneinandergeschraubte Produkte. Der einzige Unterschied ist, wer den Serverprozess verwaltet.

Falls dein externer Server zufällig `llama-server` ist, erkennt GhostType das automatisch und nutzt denselben hochwertigen Vorschlagspfad wie das eingebaute Backend. Was das bedeutet, steht unter [Qualität der Vorschläge](#qualität-der-vorschläge).

## Installation

Lade das neueste `.dmg` von der [Releases](https://github.com/mk668a/GhostType/releases)-Seite, öffne es und zieh **GhostType** in **Programme**.

### Freigabe beim ersten Start

GhostType ist nicht notarisiert. Notarisierung setzt einen kostenpflichtigen Apple-Developer-Account voraus, den dieses Projekt nicht hat. Deshalb blockiert macOS den ersten Start und verlangt eine Freigabe von Hand. Das ist einmalig.

1. Öffne **GhostType**. macOS verweigert den Start mit dem Hinweis, den Entwickler nicht überprüfen zu können.
2. Öffne **Systemeinstellungen > Datenschutz & Sicherheit** und scroll runter bis **Sicherheit**.
3. Klick neben der Meldung über die Blockade von GhostType auf **Dennoch öffnen** und bestätige mit **Öffnen**.

> Ab macOS 15 Sequoia funktioniert es nicht mehr, die App bei gedrückter Control-Taste anzuklicken und **Öffnen** zu wählen. Apple hat diese Abkürzung entfernt, die Systemeinstellungen sind der einzige Weg.

Updates, die GhostType später selbst installiert, wiederholen das nicht. Die Prüfung gilt dem ersten Start einer geladenen App, nicht einer, die sich an Ort und Stelle aktualisiert.

Wer sich das ganz sparen will, [baut die App selbst](#aus-dem-quellcode-bauen). Eine selbst kompilierte App wurde nie heruntergeladen, trägt also keine Quarantäne-Markierung und startet völlig ohne Nachfrage.

## Einrichtung

### Schritt 1: Backend wählen

Der Einrichtungsassistent öffnet sich beim ersten Start. Wähl **Eingebaut** und lade ein Modell, oder wähl **Externer Server** und trag dessen Adresse ein.

Eingebaute Modelle. Für Fließtext kommen Basismodelle zum Einsatz statt auf Dialog abgestimmter Chatmodelle: Bittet man ein Chatmodell, einen Satz zu Ende zu schreiben, antwortet es eher darauf, statt ihn fortzusetzen.

| Modell | Größe | Für | Hinweise |
|--------|-------|-----|----------|
| Qwen3.5 0.8B Base | ~0,6 GB | Fließtext | Am schnellsten. Reicht auf Macs mit 8 GB. |
| Qwen3.5 2B Base | ~1,3 GB | Fließtext | Empfohlen. Bestes Verhältnis von Tempo und Qualität. |
| Qwen3.5 4B Base | ~2,7 GB | Fließtext | Höchste Qualität. Will 16 GB oder mehr. |
| Qwen2.5-Coder 0.5B | ~0,5 GB | Code | Leichtgewichtig, für Code und technische Texte. |
| Qwen2.5-Coder 1.5B | ~1,6 GB | Code | Stärker bei Code, schwächer bei Alltagstext. |

Modelle landen in `~/Library/Application Support/GhostType/models` und verlassen deinen Mac nie.

### Schritt 2: Zwei Berechtigungen erteilen

GhostType braucht beide:

- **Eingabeüberwachung**, um zu bemerken, dass du aufgehört hast zu tippen
- **Bedienungshilfen**, um den Text rund um die Einfügemarke zu lesen und Übernommenes einzufügen

Aktiviere GhostType für beide unter **Systemeinstellungen > Datenschutz & Sicherheit**. Das Symbol in der Menüleiste zeigt dir, welche noch fehlt.

### Schritt 3: Schreib etwas

Öffne TextEdit, schreib einen halben Satz und warte. Grauer Text erscheint. Drück `Tab`.

## Qualität der Vorschläge

Zwei Dinge entscheiden darüber, ob du einen Vorschlag übernimmst oder löschst.

**Fill-in-the-Middle.** Die meisten Werkzeuge zur Autovervollständigung schicken dem Modell nur den Text vor der Einfügemarke. Dieses Modell ahnt nicht, dass der Satz hinter dir bereits weitergeht, und schreibt deshalb ein zweites Ende über das vorhandene. GhostType schickt über den `/infill`-Endpunkt von llama.cpp den Text auf beiden Seiten, sodass ein Vorschlag **innerhalb** deines Satzes landet, statt dessen Ende zu verdoppeln.

**Eingeschränkte Generierung.** Ein Modell, das einen Satz vervollständigen soll, antwortet manchmal mit einem Codeblock, einer Wiederholung in Anführungszeichen oder drei Absätzen Erklärung. Das hinterher aufzuräumen ist Raterei. Stattdessen kompiliert GhostType eine GBNF-Grammatik und übergibt sie dem Sampler, wodurch solche Tokens von vornherein unerreichbar sind. Das Modell verbringt keine Zeit damit, Text zu erzeugen, der ohnehin weggeworfen wird.

| Einstellung | Grammatik | Sinnvoll bei |
|-------------|-----------|--------------|
| Einzeilig | Sperrt Zeilenumbrüche und führende Codeblöcke | E-Mail, Chat, Browserfelder (Standard) |
| Bis zu einigen Zeilen | Erlaubt bis zu 4 Zeilen | Editoren, Notizen, mehrzeilige Felder |
| Ohne Einschränkung | Keine | Ein Modell verhält sich unter Einschränkungen seltsam |

Beide Funktionen setzen einen Server voraus, der die API von llama.cpp spricht. Beim eingebauten Backend ist das immer der Fall, bei einem externen `llama-server` ebenfalls. Gegenüber einem bloß OpenAI-kompatiblen Server weicht GhostType auf Chat Completions mit einer Cursor-Markierung aus. Das funktioniert weiterhin, ist aber spürbar gröber.

## Tastaturkürzel

| Taste | Aktion |
|-------|--------|
| `Tab` | Vorschlag übernehmen |
| `Esc` | Vorschlag verwerfen |
| `Cmd + Option + \` | Vorschlag manuell anfordern |
| `Cmd + Shift + G` | GhostType ein- und ausschalten |

Alle Kürzel lassen sich in den Einstellungen ändern.

## App-Kompatibilität

| App-Typ | Automatische Auslösung | Warum |
|---------|------------------------|-------|
| TextEdit, Notizen, Pages | Ja | Vollständige Unterstützung der Bedienungshilfen-API |
| Webfelder in Safari und Chrome | Ja | Weicht auf den Tastenpuffer aus |
| Mail, Slack, Discord | Nur manuell | Automatik gerät mit deren eigener Eingabeverarbeitung aneinander |
| IDEs, Terminals | Aus | Haben bereits eigene Vervollständigung |

Die Automatik pausiert außerdem, solange eine Eingabemethode außerhalb von ASCII (Japanisch, Chinesisch, Koreanisch) gerade komponiert, und stört so nie mitten in der Umwandlung.

## Was es nicht tut

- Keine Inferenz in der Cloud. Es gibt kein Feld für einen API-Schlüssel, weil es keine API gibt, in die man einen stecken könnte.
- Keine Telemetrie, keine Analytik, keine Aufzeichnung der Eingaben.
- Kein Konto, kein Abo, kein Nutzungslimit.
- Es schreibt deinen Text nicht um, übersetzt ihn nicht und strukturiert ihn nicht neu. Es beendet den Satz, den du angefangen hast.

## Systemvoraussetzungen

| | Minimum | Empfohlen |
|--|---------|-----------|
| **macOS** | 14.0 Sonoma | 15.0 Sequoia |
| **Chip** | Apple M1 | Apple M2 Pro oder besser |
| **Speicher** | 8 GB | 16 GB oder mehr |
| **Festplatte** | 1 GB plus Modell | 5 GB |

## Datenschutz

Jeder Vorschlag entsteht auf deinem Mac. Das eingebaute Backend spricht mit einem `llama-server`-Prozess auf `127.0.0.1`, das externe mit der Loopback-Adresse, die du eingetragen hast. Abgesehen von der Suche nach eigenen Updates stellt GhostType keine weiteren Netzwerkanfragen.

## Fehlerbehebung

**Der Schalter steht in den Systemeinstellungen auf an, GhostType meldet aber, die Berechtigung fehle.**
Das trifft alle, die von 0.3.1 oder älter aktualisieren. macOS knüpft jede Bedienungshilfen-Berechtigung an die Codesignatur der App, die sie erhalten hat, und jede Version bis 0.3.1 war mit einem Hash des Builds selbst signiert, der sich mit jeder Version änderte. 1.0.0 verwendet stattdessen ein festes Zertifikat, damit hört es hier auf. Auf deinem Mac liegt aber noch die alte Regel. Das Umlegen des Schalters aktualisiert nur die Berechtigung, ohne die daran hängende Regel neu zu schreiben. Deshalb wird die App weiter abgewiesen, während der Schalter auf an steht.

Aus- und wieder Einschalten hilft nicht, und GhostType mit dem Minus-Knopf aus der Liste zu entfernen ebenso wenig. Der gespeicherte Eintrag muss gelöscht werden:

```bash
sudo tccutil reset Accessibility com.ghosttype.app
sudo tccutil reset ListenEvent com.ghosttype.app
sudo killall tccd
```

Starte GhostType danach neu und erteile die Berechtigung, wenn danach gefragt wird. Einmal genügt. Ob dich das betrifft, verrät ein `Failed to match existing code requirement` hier:

```bash
log show --last 5m --predicate 'process == "tccd"' | grep -i ghosttype
```

**In anderen Apps erscheinen keine Vorschläge.**
Sieh in der Menüleiste nach. Steht dort, dass Bedienungshilfen oder Eingabeüberwachung fehlen, öffne den passenden Bereich der Systemeinstellungen und aktiviere GhostType. Die App startet sich innerhalb weniger Sekunden selbst neu. Ein Build aus dem Quellcode signiert die App neu, und ohne angegebene Signaturidentität ändert sich die Signatur jedes Mal. Dann verlangt macOS nach jedem Build erneut die Bedienungshilfen. Führe `scripts/make-signing-cert.sh` einmal aus und baue mit gesetztem `GHOSTTYPE_SIGN_IDENTITY`, dann bleibt die Berechtigung über Builds hinweg erhalten.

**Im Testfeld der Einstellungen klappt es, sonst nirgends.**
Das ist genau die Bedienungshilfen-Berechtigung. Das Testfeld sitzt innerhalb von GhostType und braucht daher keine Systemberechtigung.

**Der Status meldet „Ready", aber es erscheint kein grauer Text.**
Prüf, ob ein Modell geladen ist (eingebaut) oder der Server läuft (extern). Probier das manuelle Kürzel. Sieh nach, ob die App auf der Ausschlussliste steht.

**Das eingebaute Backend meldet fehlende llama.cpp-Binaries.**
Du benutzt einen Build ohne sie. Führe `scripts/fetch-llama.sh` aus und baue neu, oder wechsel auf einen externen Server.

## Aus dem Quellcode bauen

```bash
git clone https://github.com/mk668a/GhostType.git
cd GhostType
open GhostType.xcodeproj
```

Der Build holt beim ersten Durchlauf die festgelegten llama.cpp-Binaries und legt sie ins App-Bundle. Ein separater Einrichtungsschritt entfällt damit. Um sie von Hand zu holen oder für Intel zu bauen:

```bash
./scripts/fetch-llama.sh                 # host architecture
LLAMA_ARCH=x64 ./scripts/fetch-llama.sh  # Intel
GHOSTTYPE_SKIP_LLAMA=1 xcodebuild ...    # skip, external backend only
```

Weitere Skripte:

```bash
./scripts/create-dmg.sh   # build the DMG installer
./scripts/install.sh      # build and install into /Applications
```

Erfordert Xcode und die Command Line Tools (`xcode-select --install`).

## Architektur

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

## Danksagung

Die Inferenz läuft auf [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT). Die Fließtextmodelle sind GGUF-Konvertierungen von Qwen3.5 Base durch [mradermacher](https://huggingface.co/mradermacher), die Codemodelle sind die Konvertierungen von [Qwen2.5-Coder](https://github.com/QwenLM/Qwen2.5-Coder) durch [ggml-org](https://huggingface.co/ggml-org). Beide Modellfamilien stehen unter Apache-2.0.

## Lizenz

[MIT](../../LICENSE). Nutzen, forken, kommerziell ausliefern. Ohne Gegenleistung.

---

**GhostType** *Type less. Think more.*
