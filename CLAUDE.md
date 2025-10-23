# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BloodPressureCam is an iOS 16+ SwiftUI application for tracking blood pressure readings through camera capture and manual entry. Users can photograph blood pressure monitors, annotate readings with metadata (feeling, posture, weight), view statistics with trend charts, and export PDF reports.

**Platform**: iOS 16+ (requires SwiftUI Charts and ImageRenderer)
**Language**: Swift
**Build System**: XcodeGen with `project.yml`

## Essential Commands

### Project Generation
```bash
xcodegen generate  # Generate BloodPressureCam.xcodeproj from project.yml
```
**IMPORTANT**: Run this command after any changes to `project.yml`, target configurations, or resource additions.

### Building and Running
```bash
open BloodPressureCam.xcodeproj  # Open in Xcode
```
- Run: `⌘R` in Xcode
- Clean build: `Shift+⌘+K` before running

### Testing
```bash
# Via Xcode UI
⌘U  # Run all tests

# Via command line (after xcodegen generate)
xcodebuild -scheme BloodPressureCam \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Architecture

### Data Flow
The app uses a centralized observable store pattern:
- **MeasurementStore**: Single source of truth for all readings, injected via `@EnvironmentObject`
- Data persists to JSON file at `Documents/blood-pressure-readings.json`
- Photos stored separately in `Documents/ReadingPhotos/` directory
- All persistence operations run on background queue, UI updates on main thread

### Core Components

**Models** (`Sources/Models/`)
- `BloodPressureReading`: Main domain model with systolic, diastolic, heart rate, metadata
- Enums: `MeasurementCategory`, `Feeling`, `MeasurementPosture`, `MeasurementLocation`, `BloodPressureLevel`
- Computed `level` property classifies readings (optimal → hypertensive crisis)

**Services** (`Sources/Services/`)
- `MeasurementStore`: CRUD operations, filtering, photo coordination
- `PhotoStorage`: Image persistence to disk with unique filenames
- `ReportGenerator`: PDF export with SwiftUI ImageRenderer

**Views** (`Sources/Views/`)
- `ContentView`: TabView container
- Tab views: `RecordsView`, `StatisticsView`, `CaptureEntryView`, `ReportsView`, `SettingsView`
- `CameraCaptureView`: Camera permission handling and capture
- `ManualEntryView`: Form for reading entry/editing

**Utilities** (`Sources/Utilities/`)
- `DateRangeOption`: Time period filtering (last 7/30/90 days, all time)
- `Color+Hex`: Hex color string conversion
- `ReportMetrics`: Statistics calculations for report generation

### View Architecture
All views receive `MeasurementStore` via:
```swift
@EnvironmentObject var store: MeasurementStore
```
Injected at app root in `BloodPressureCamApp.swift`.

## Development Workflow

### Adding New Features
1. Update models in `Sources/Models/` if data structure changes
2. Extend `MeasurementStore` if new persistence operations needed
3. Create/modify views in `Sources/Views/`
4. Add tests in `Tests/` for any service logic
5. Run `xcodegen generate` if adding new source files or resources
6. Run tests (`⌘U`) before committing

### Working with Resources
- Add assets to `Sources/Resources/Assets.xcassets/`
- App icon assets live in `AppIcon.appiconset/` with complete iPhone/iPad/marketing sizes
- Update `Contents.json` when adding new asset catalogs
- Resources automatically included via `project.yml` resource path

### Dependencies
- Prefer Swift Package Manager for external dependencies
- Update `project.yml` packages section and regenerate project
- No CocoaPods used in this project

### Privacy & Permissions
- Camera usage description in `Sources/Info.plist`
- Photo library usage description in `Sources/Info.plist`
- Camera permissions handled in `CameraCaptureView` with user guidance

## Testing Notes

- Test file: `Tests/MeasurementStoreTests.swift`
- Tests use temporary directories, no fixtures required
- Focus tests on `MeasurementStore` persistence and filtering logic
- View testing requires XCTest UI testing (not currently implemented)

## Device Testing

For real device deployment:
1. Configure signing in Xcode "Signing & Capabilities"
2. Enable Developer Mode on iOS device (Settings → Privacy & Security)
3. Trust developer certificate when prompted
4. See `Documentation/DEVICE_TESTING.md` for detailed steps

## Important Documentation

- `Documentation/INSTALLATION.md`: Local setup steps
- `Documentation/DEVICE_TESTING.md`: Real device deployment
- `Documentation/APP_STORE_GLOBAL_RELEASE.md`: App Store submission checklist
- `Documentation/AD_FREE_PAID_MONETIZATION_PLAN.md`: Monetization strategy
- `Documentation/AD_NETWORK_OPTIONS.md`: Ad network integration guidance

## Code Conventions

- SwiftUI declarative views with minimal business logic
- Observable stores (`@Published` properties) for state management
- Async operations on background queues, UI updates on main thread
- Localized strings in Chinese (zh_CN) for display names
- Enums with `CaseIterable` and `Identifiable` for form pickers
- Codable conformance for all persisted models
