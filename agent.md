# Codex Agent Guide for BloodPressureCam

This guide condenses the essential knowledge from the BloodPressureCam codebase and documentation so Codex agents can work efficiently and stay aligned with project conventions.

## Project Snapshot
- **Platform**: iOS 16+ (SwiftUI, Charts)
- **Purpose**: Capture blood pressure monitor photos, annotate readings, analyse trends, export reports.
- **Targets**:
  - `BloodPressureCam` (app)
  - `BloodPressureCamTests` (unit tests)
- **Key Modules**:
  - `Models`: Domain entities (`BloodPressureReading`, etc.).
  - `Services`: Persistence (`MeasurementStore`), media handling.
  - `ViewModels` & `Views`: SwiftUI UI logic, including tabs for Records, Statistics, Capture, Reports, Settings.
  - `Utilities`: Helpers (date ranges, hex colors, report metrics).
  - `Resources`: Asset catalog (`Assets.xcassets`) with custom app icon.

## Local Environment
1. macOS 13+, Xcode 15 with Command Line Tools.
2. Install XcodeGen once: `brew install xcodegen`.
3. Repository root contains `project.yml`; use XcodeGen to regenerate the Xcode project when targets/resources change.
4. App icon assets live at `Sources/Resources/Assets.xcassets/AppIcon.appiconset/` and already include full iPhone/iPad/marketing PNGs.

## Build & Run
1. From project root: `xcodegen generate` (creates `BloodPressureCam.xcodeproj`).
2. Open the project: `open BloodPressureCam.xcodeproj`.
3. Select `BloodPressureCam` target and a simulator or device.
4. Run (`⌘R`) for build + launch. Clean builds use `Shift+⌘+K` before re-running.
5. For real device testing follow `Documentation/DEVICE_TESTING.md` (signing, Developer Mode, trust flow).

## Testing
- Unit tests live under `Tests/MeasurementStoreTests.swift`.
- Run via Xcode (`⌘U`) or CLI: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test` (requires project generation first).
- Tests rely on temporary directories; no additional fixtures needed.

## Documentation Highlights
- `Documentation/INSTALLATION.md`: step-by-step local setup.
- `Documentation/DEVICE_TESTING.md`: real device deployment procedure.
- `Documentation/APP_STORE_GLOBAL_RELEASE.md`: checklist for global App Store launch.
- `Documentation/AD_FREE_PAID_MONETIZATION_PLAN.md`: plan for free-with-ads vs paid edition.
- `Documentation/AD_NETWORK_OPTIONS.md`: vetted ad network choices, compliance notes, personal setup steps.
- Additional usage/testing notes in `Documentation/USAGE.md`, `TESTING.md`, `TECHNICAL_NOTES.md` (review if task touches those areas).

## Implementation Guidelines
- Maintain SwiftUI architectural style: views backed by observable stores, lightweight view models.
- Keep new assets in `Sources/Resources` and update relevant `Contents.json`.
- When adding dependencies prefer Swift Package Manager; update `project.yml` accordingly and regenerate project.
- Persisted data flows use `MeasurementStore`; respect its APIs when extending storage features.
- Follow privacy/consent requirements laid out in monetization and release docs if introducing ads or analytics.

## Contribution Workflow
1. Confirm Xcode project is regenerated after structural changes (`xcodegen generate`).
2. Run unit tests before submission.
3. Update or add documentation for user-facing or compliance changes.
4. For release/business tasks, synchronise with the relevant plan documents listed above.

With this reference, Codex agents can orient quickly and perform code or documentation work while respecting build, testing, and compliance expectations.
