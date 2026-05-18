# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
swift build                        # debug build (fast iteration)
swift build -c release             # release binary only
make build                         # alias for release build
make bundle                        # build + generate icon + create ASRInput.app + ad-hoc sign
make run                           # bundle, kill any running instance, open app
make install                       # copy bundle to /Applications
make clean                         # remove .build/, ASRInput.app, DMG
```

**Validate plist changes:**
```bash
plutil -lint Sources/ASRInput/Resources/Info.plist
```

**Run behavior checks (the only automated tests):**
```bash
swift run CoreBehaviorCheck
```

`CoreBehaviorCheck` is a standalone executable target (not an XCTest suite) defined in `Package.swift`. It imports `LLMRuleCore` and `OverlayHUDCore` and uses `require()` assertions — exit code non-zero means failure. Run it after any change to those two library targets.

## Architecture

Three SwiftPM targets:

| Target | Kind | Role |
|--------|------|------|
| `ASRInput` | executable | Full app — menu bar, hotkey, overlay, injection, settings |
| `LLMRuleCore` | library | LLM prompt builder (`LLMRulePrompt`) + output sanitizer (`LLMOutputSanitizer`) |
| `OverlayHUDCore` | library | Layout math for the floating capsule (`OverlayHUDLayout`, `OverlayHUDMetrics`) |
| `CoreBehaviorCheck` | executable | Behavior tests for the two libraries above |

`LLMRuleCore` and `OverlayHUDCore` have no AppKit dependencies and are safe to unit-test without a running app.

### Core Data Flow

```
HotkeyManager (CGEvent tap)
    └─> AppDelegate.hotkeyDidStart/hotkeyDidStop
            └─> Transcriber.start / .stop
                    ├── SpeechTranscriber  (Apple Speech framework, streaming partial results)
                    └── WhisperTranscriber (records WAV → multipart POST to OpenAI-compatible endpoint)
            └─> LLMRefiner.refine (optional, guarded by llmEnabled + llmAPIKey)
                    └─> LLMRulePrompt.buildSystemPrompt (in LLMRuleCore)
                    └─> LLMOutputSanitizer.sanitize (strips <think> blocks, "Output:" markers)
            └─> TextInjector.inject
                    └─> saves clipboard, switches input source to ASCII if needed,
                        simulates Cmd+V via CGEvent, restores clipboard
            └─> OverlayPanel (floating capsule, shows partial text + waveform + refining state)
```

### Key Design Points

- **`Transcriber` protocol** (`SpeechTranscriber.swift`) is the seam between backends. Swap backends by changing `Preferences.shared.sttBackend`; `AppDelegate.makeTranscriber()` is the factory. Both backends call `onPartial` for streaming updates and `onLevel` for waveform amplitude.
- **`Preferences`** wraps `UserDefaults.standard` with typed accessors — no model layer. All persistent state lives here.
- **`AppLogger`** uses `os.Logger` subsystems (`main`, `speech`, `whisper`, `llm`, `hotkey`, `inject`). Use the existing subsystems rather than `print`.
- **`InputSourceSwitcher`** temporarily forces ASCII input source before `Cmd+V` to avoid CJK input method interception, then restores it.
- **`OverlayHUDLayout`** (in `OverlayHUDCore`) is pure math — width clamping and panel sizing. `OverlayPanel` and `WaveformView` are the AppKit rendering layer.
- **Info.plist is embedded at link time** via `unsafeFlags` in `Package.swift` (no `.app` bundle needed for the raw binary to have metadata).

## Permissions Required

The app needs three macOS permissions: Microphone (for `AVAudioEngine`), Speech Recognition (for `SFSpeechRecognizer`), and Accessibility (for `CGEvent.tapCreate` and `CGEvent.post`). `PermissionManager` requests them at launch; `HotkeyManager.start()` will retry on a 2-second timer until Accessibility is granted.

## Testing & Verification Workflow

Until XCTest targets exist, the minimum verification before committing:
1. `swift run CoreBehaviorCheck` — must print `CoreBehaviorCheck passed`
2. `make bundle` — must succeed without errors
3. `make run` — manual smoke test: hotkey triggers recording, transcription returns text, text is injected into a text field
