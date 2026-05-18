# Repository Guidelines

## Project Structure & Module Organization

ASRInput is a SwiftPM macOS 14 menu-bar app. The executable target is defined in `Package.swift` and lives under `Sources/ASRInput/`.

- `Sources/ASRInput/*.swift`: app code, including menu-bar control, hotkey handling, transcription, text injection, settings, logging, and overlay UI.
- `Sources/ASRInput/Resources/Info.plist`: bundle metadata and privacy permission strings.
- `scripts/make_icon.swift`: generates the base icon image used by the bundle.
- `Makefile`: build, bundle, run, install, and cleanup automation.

Do not commit generated artifacts such as `.build/`, `ASRInput.app/`, `.DS_Store`, or local `.omx/` state.

## Build, Test, and Development Commands

- `swift build`: quick debug build of the SwiftPM executable.
- `swift build -c release`: release build used by the bundle flow.
- `make build`: release build through the project Makefile.
- `make bundle`: builds, generates icons, creates `ASRInput.app`, and ad-hoc signs it.
- `make run`: rebuilds the bundle, stops any running `ASRInput`, and opens the app.
- `make install`: copies the bundled app to `/Applications`.
- `make clean`: removes SwiftPM build output and generated app artifacts.

Validate plist changes with `plutil -lint Sources/ASRInput/Resources/Info.plist`.

## Coding Style & Naming Conventions

Use standard Swift style with 4-space indentation. Keep types in `PascalCase`, functions and properties in `camelCase`, and file names aligned with the main type they define, for example `HotkeyManager.swift`. Prefer `final class` for non-inherited reference types. Keep AppKit callbacks marked `@objc` only where selectors require them. Reuse existing singletons and helpers such as `Preferences.shared` and `AppLogger` before adding new global state.

## Testing Guidelines

There is currently no `Tests/` directory and no `make test` target. For behavior changes, add focused tests or a small executable check before refactoring shared logic. Until a test target exists, verify with at least `swift build`, `make bundle`, `plutil -lint Sources/ASRInput/Resources/Info.plist`, and a manual `make run` smoke test for permission, hotkey, transcription, and text injection flows.

## Commit & Pull Request Guidelines

Git history is currently minimal (`init: empty project`), so keep new commit subjects short, imperative, and intent-focused. For agent-authored commits, include Lore-style trailers when useful: `Constraint:`, `Rejected:`, `Confidence:`, `Scope-risk:`, `Tested:`, and `Not-tested:`.

Pull requests should describe user-visible behavior, list verification commands, mention permission or signing impacts, and include screenshots or short recordings for UI changes.

## Security & Configuration Tips

Do not hardcode API keys, endpoints with secrets, or user-specific paths. Keep microphone, speech-recognition, accessibility, and Apple Events permission text accurate whenever app capabilities change.
