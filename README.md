# ASRInput

A lightweight macOS menu-bar speech input tool.

ASRInput turns speech into text and inserts the result into the currently active app. It supports Apple Speech for quick local macOS integration, an OpenAI-compatible Whisper endpoint for custom ASR backends, a floating transcription overlay, configurable global hotkeys, and optional LLM post-processing for conservative text cleanup.

---

## Features

### Real-time Speech Input

- Press a global hotkey to start and stop recording.
- Shows partial transcription while recording when using Apple Speech.
- Inserts final text into the active text field through clipboard paste simulation.
- Temporarily switches to an ASCII input source before paste to avoid CJK input method interception.

### Multiple Speech Backends

- Apple Speech backend using `SFSpeechRecognizer`.
- Whisper-compatible backend that records WAV audio and uploads it to a configured endpoint.
- Backend selection is persisted in macOS `UserDefaults`.

### Floating Overlay HUD

- Compact always-on-top overlay while recording.
- Displays live transcription text and audio waveform level.
- Shows a refining state when LLM cleanup is enabled.

### LLM Post-processing

- Optional OpenAI-compatible chat completion refinement.
- Conservative prompt rules: fix obvious ASR errors without rewriting content.
- Supports punctuation, sentence breaking, filler-word removal, and custom user rules.
- Sanitizes model output by removing `<think>` blocks and common final-output labels.

### Menu Bar Settings

- Runs as a macOS menu-bar app.
- Settings window for hotkey, speech backend, language, Whisper endpoint, and LLM options.
- Built-in Edit menu support so text fields can use standard shortcuts like `Cmd+V`.

---

## Project Structure

```text
ASRInput/
├── Sources/
│   ├── ASRInput/
│   │   ├── AppDelegate.swift          # App lifecycle and recording flow
│   │   ├── HotkeyManager.swift        # Global hotkey event tap
│   │   ├── SpeechTranscriber.swift    # Apple Speech backend
│   │   ├── WhisperTranscriber.swift   # Whisper-compatible backend
│   │   ├── LLMRefiner.swift           # Optional LLM cleanup
│   │   ├── TextInjector.swift         # Clipboard paste injection
│   │   ├── OverlayPanel.swift         # Floating HUD window
│   │   ├── SettingsWindow.swift       # AppKit settings UI
│   │   └── Resources/Info.plist       # Bundle metadata and permission strings
│   ├── LLMRuleCore/
│   │   ├── LLMRulePrompt.swift        # Conservative refinement prompt builder
│   │   └── LLMOutputSanitizer.swift   # LLM output cleanup
│   └── OverlayHUDCore/
│       └── OverlayHUDLayout.swift     # Pure HUD layout math
├── Tests/
│   └── CoreBehaviorCheck/main.swift   # Executable behavior checks
├── scripts/
│   └── make_icon.swift                # App icon generation
├── Makefile                           # Build, bundle, run, install, DMG
├── Package.swift                      # SwiftPM package definition
└── README.md
```

---

## How It Works

1. Start ASRInput.
   - The app appears in the macOS menu bar.
2. Press the configured hotkey.
   - Default hotkey is `Fn`.
   - The app starts audio capture and displays the floating overlay.
3. Speak naturally.
   - Apple Speech streams partial text.
   - Whisper backend records audio and transcribes after stop.
4. Release or press the hotkey again to stop.
   - ASRInput trims the final transcription.
   - If LLM cleanup is enabled and configured, it refines the text conservatively.
5. Insert text automatically.
   - The app saves the current clipboard, copies the final text, simulates `Cmd+V`, then restores the clipboard.

---

## System Requirements

- macOS 14 or later
- Swift 5.9 or later
- Command Line Tools or Xcode toolchain
- Required macOS permissions:
  - Microphone
  - Speech Recognition
  - Accessibility

Accessibility permission is required for the global hotkey event tap and paste injection.

---

## Installation

### Clone

```bash
git clone https://github.com/lazierhk/asrinput.git
cd asrinput
```

### Build

```bash
swift build
```

### Create App Bundle

```bash
make bundle
```

This creates and ad-hoc signs:

```text
ASRInput.app
```

### Run

```bash
make run
```

### Install to Applications

```bash
make install
```

### Create DMG

```bash
make dmg
```

The generated disk image is:

```text
.build/ASRInput.dmg
```

---

## Build Commands

```bash
swift build                        # Debug build
swift build -c release             # Release binary only
make build                         # Release build
make bundle                        # Build app bundle and ad-hoc sign it
make run                           # Bundle, stop existing app, then open it
make install                       # Copy ASRInput.app to /Applications
make dmg                           # Build a distributable DMG
make clean                         # Remove generated build artifacts
```

Validate the app metadata plist:

```bash
plutil -lint Sources/ASRInput/Resources/Info.plist
```

Run the current behavior checks:

```bash
swift run CoreBehaviorCheck
```

---

## Configuration

Open the menu-bar app and choose Settings.

### Hotkey

- Default: `Fn`
- Can be changed from the Hotkey tab.
- Supports regular key combinations such as control, option, shift, and command modifiers.

### Speech Recognition

- Apple Speech backend:
  - Uses macOS Speech framework.
  - Supports live partial transcription.
- Whisper backend:
  - Sends recorded WAV audio to a configured OpenAI-compatible endpoint.
  - Configure endpoint, model, and API key in Settings.

Default language is `zh-CN`.

### LLM Cleanup

The LLM cleanup tab controls:

- Base URL
- API key
- Model
- Punctuation cleanup
- Sentence breaking
- Filler-word removal
- Custom correction rules

The prompt is intentionally conservative: it should correct obvious recognition mistakes without changing meaning, tone, or order.

---

## Usage Tips

### First Launch

macOS may ask for permissions on first use. Grant:

- Microphone access for recording
- Speech Recognition for Apple Speech
- Accessibility for hotkey capture and text insertion

If the hotkey does not work, open:

```text
System Settings -> Privacy & Security -> Accessibility
```

Then enable ASRInput.

### Menu Bar Controls

- Open Settings.
- Change language.
- Toggle LLM optimization.
- Quit the app.

### Text Insertion

ASRInput inserts text into the app that was active before the overlay flow completes. For best results, keep the target text field focused before starting recording.

---

## Troubleshooting

### Hotkey Does Not Start Recording

- Check Accessibility permission.
- Restart ASRInput after granting permission.
- Try `make run` during development to relaunch a fresh bundle.

### No Audio or Empty Transcription

- Check Microphone permission.
- Confirm the input device works in macOS settings.
- For Apple Speech, confirm Speech Recognition permission is granted.

### Whisper Backend Fails

- Confirm the endpoint is reachable.
- Confirm the API key and model name are correct.
- Check whether the endpoint accepts OpenAI-compatible multipart audio transcription requests.

### Text Is Not Inserted

- Check Accessibility permission.
- Make sure a text field is focused before stopping recording.
- Some secure input fields may block simulated paste.

### Build Warning About `Info.plist`

SwiftPM may warn that `Sources/ASRInput/Resources/Info.plist` is unhandled. The executable target embeds it at link time through linker flags in `Package.swift`, and the Makefile also copies it into the generated app bundle.

---

## Roadmap

- Add a formal XCTest target.
- Add signed and notarized release packaging.
- Add a first-run permission status panel.
- Improve Whisper backend diagnostics.
- Add import/export for settings.
- Add release screenshots or demo GIF.

---

## License

License is not declared yet. Add a `LICENSE` file before public distribution.
