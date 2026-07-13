# Repository Guidelines

## Project Structure & Module Organization

This is a SwiftPM macOS menu-bar app for meeting audio capture.

- `Package.swift`: package, products, targets, framework links, and test settings.
- `Sources/MeetingAudioCaptureApp/`: AppKit status-bar UI and user interactions.
- `Sources/MeetingAudioCaptureCore/`: recording engine, permissions, audio conversion, mixing, and segmented file writing.
- `Tests/MeetingAudioCaptureCoreTests/`: Swift Testing tests for audio chunks, timeline mixing, output formats, and segment merging.
- `Resources/Info.plist`: app bundle metadata and microphone usage description.
- `Scripts/package-app.sh`: release build and `.app` bundle creation.
- `docs/feature-notes.md`: completed feature notes and maintenance constraints.

## Build, Test, and Development Commands

Use a project-local Clang module cache in Codex or restricted environments:

```sh
CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build
CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test
Scripts/package-app.sh
open .build/release/MeetingAudioCapture.app
```

- `swift build`: compiles the app and core library.
- `swift test`: runs the core audio unit tests.
- `Scripts/package-app.sh`: creates a runnable release `.app` bundle.

## Coding Style & Naming Conventions

Use Swift defaults: 4-space indentation, clear type names, and small focused types. Keep UI concerns in the app target and recording/audio logic in the core target. Prefer explicit domain names such as `RecordingMode`, `SegmentedAudioFileWriter`, and `TimelineAudioMixer`. Add comments only for non-obvious macOS, audio, or permission behavior.

## Testing Guidelines

Tests use Swift Testing. Add tests for pure logic whenever possible, especially file naming, mixing, output formats, segmentation, merging, settings stores, and error handling. Live meeting capture depends on macOS permissions and hardware, so keep automated completion independent of real-device recording.

## Commit & Pull Request Guidelines

The current history uses concise imperative commits, for example `Initial MVP meeting recorder`. Keep commits scoped to one feature or fix. PRs should include a short summary, test commands run, manual recording checks when relevant, and screenshots only for visible UI changes.

## Security & Configuration Tips

Do not commit recordings, credentials, or local build outputs. Keep `.build/` ignored. Be careful with microphone and screen-recording permission changes; explain user-visible permission prompts in README or PR notes.
