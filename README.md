# TimeNest

TimeNest is a local-first iPhone calendar app for managing daily schedules and subscribed public holidays. It is built with Swift, SwiftUI, and Apple-native local storage patterns for a small, maintainable MVP.

## Main Features

- **Month / Week / Day calendar views**: browse schedules from a monthly grid, a 7-day week view, or a single-day timeline.
- **Schedule management**: create, edit, and delete local calendar events.
- **Holiday subscriptions**: enable Japan, China, Korea, and United States holiday regions and sync public ICS feeds selected by the user.
- **Multilingual UI**: Japanese, Simplified Chinese, English, and Korean resources are included.
- **Local-first design**: schedule data, display settings, holiday subscriptions, and holiday cache data are stored locally by default.
- **File sharing**: export and import TimeNest data files for manual backup or transfer.

## Supported Languages

- Japanese (`ja`)
- Simplified Chinese (`zh-Hans`)
- English (`en`)
- Korean (`ko`)
- System language mode is available in the app settings.

## Development Environment

- Xcode 15 or later
- iOS 17.0 or later
- Swift 5.9
- macOS with iOS Simulator for local build and test verification

## Build

```bash
xcodebuild \
  -project TimeNest.xcodeproj \
  -scheme TimeNest \
  -destination 'generic/platform=iOS' \
  clean build
```

## Test

```bash
xcodebuild \
  -project TimeNest.xcodeproj \
  -scheme TimeNest \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

If the selected simulator is not installed, choose an available iOS Simulator from Xcode and replace the destination.

## Privacy Summary

TimeNest is designed as a local-first calendar app. User-created schedules, local settings, holiday subscription URLs, and cached holiday data are stored on the device. The app does not include advertising, analytics, tracking SDKs, account sign-in, or cloud sync in the current repository implementation.

Holiday sync accesses public HTTPS ICS URLs when the user enables or tests a holiday subscription. The final App Store privacy policy URL and App Privacy Labels must be reviewed before release.

## App Store Release Notes

Before submitting to App Store Connect, confirm:

- Bundle ID, signing team, certificates, and provisioning profiles.
- App icon, version, build number, screenshots, subtitle, description, keywords, support URL, and privacy policy URL.
- Privacy Manifest and App Privacy Labels match the current implementation.
- TestFlight has covered fresh install, upgrade install, offline behavior, invalid ICS URL handling, multilingual UI, dark/light mode, and small/large screens.
- Placeholder or disabled feature entries are either intentionally kept as MVP limitations or removed before production release.

See `Docs/AppStoreReleaseChecklist.md`, `Docs/TestFlightChecklist.md`, `Docs/PrivacyPolicyDraft.md`, and `Docs/AppStoreMetadataDraft.md` for release preparation drafts.
