# TimeNest

TimeNest is a local-first iOS calendar app built with Swift and SwiftUI. It combines month, week, and day schedule views with shift and work-time records, public-holiday subscriptions, and an in-app language setting. User-created calendar data is stored on the device with SwiftData.

## Features

- Month, week, and day calendar views with shared navigation and footer controls.
- Create, edit, and delete timed or all-day events.
- Shift templates, shift entry, same-day shift replacement, and shift deletion.
- Clock-in, clock-out, rest time, transport fee, and hourly-rate records.
- Work statistics for a selected date range.
- Public-holiday subscriptions and ICS synchronization for Japan, China, Korea, and the United States.
- Japanese, Simplified Chinese, English, and Korean UI resources, plus a system-language mode.
- Light, dark, and system appearance settings.
- A calendar banner-ad container backed by Google Mobile Ads.

The current codebase does not implement an in-app purchase or other user-facing remove-ads flow. `AdConfiguration` controls whether the banner is compiled into the calendar UI, and the checked-in configuration uses Google's test ad identifiers. Production ad identifiers and the intended ad-removal policy must be finalized before release.

## Technology

- Swift 5.9
- SwiftUI
- SwiftData local persistence
- iOS 17.0 or later
- Tuist project description with a checked-in Xcode project/workspace
- Google Mobile Ads through Swift Package Manager

## Local Build

Requirements:

- Xcode with an iOS 17 or later SDK
- A simulator installed locally
- Network access when Swift Package Manager first resolves Google Mobile Ads

The repository includes the `TimeNest` scheme. A simulator build can be run with:

```bash
xcodebuild \
  -scheme TimeNest \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  build
```

Replace the destination with an installed simulator when necessary. Signing, Bundle ID, target, and scheme settings should be managed in Xcode or `Project.swift`; release credentials are not stored in this README.

## Project Layout

```text
TimeNest/
  App/                 App entry point and root view
  Application/         Calendar, event, holiday, reminder, and import/export use cases
  Domain/              Models and business rules
  Infrastructure/      SwiftData, notifications, ICS, holiday cache, ads, and adapters
  Presentation/        Calendar, editor, settings, statistics, day detail, and ad views
  Resources/           App icons and localized strings
  Shared/              Date, localization, notification, and theme utilities
Tests/TimeNestTests/    Unit-test sources
Docs/                  App Store, TestFlight, metadata, and privacy drafts
Project.swift          Tuist project definition
```

## Localization

UI strings are maintained in all four `Localizable.strings` files:

- `TimeNest/Resources/ja.lproj/Localizable.strings`
- `TimeNest/Resources/zh-Hans.lproj/Localizable.strings`
- `TimeNest/Resources/en.lproj/Localizable.strings`
- `TimeNest/Resources/ko.lproj/Localizable.strings`

When adding or changing UI text:

1. Reuse an existing `LocalizedString` key when it has the same meaning.
2. Add every new key to `Localizable.swift` and all four language files in the same change.
3. Resolve app UI text through `LocalizationManager` so the in-app language selection is respected.
4. Do not translate user-entered event titles or customized shift names.
5. Keep holiday display names region-native: Japanese holidays in Japanese, Chinese holidays in Chinese, Korean holidays in Korean, and US holidays in English.

## Data And Privacy

- Events and work information are stored locally with SwiftData.
- Display settings and holiday-subscription choices are stored locally in app preferences.
- Downloaded holiday data is cached on the device.
- Holiday synchronization sends HTTPS requests to the public ICS provider selected in Settings.
- Banner ads use Google Mobile Ads when `AdConfiguration.isEnabled` is `true`; SDK behavior and App Store privacy disclosures must be reviewed against the production configuration.
- The app has no account sign-in or cloud synchronization in the current implementation.

Uninstalling the app removes its local container under normal iOS behavior. Existing SwiftData entities and decoding compatibility must be treated as user-data migration code and should not be removed as ordinary cleanup.

## App Store Release Checklist

Before submission, confirm:

- Replace Google test ad identifiers with the approved production configuration, or disable ads intentionally.
- Decide and document the remove-ads policy; no purchase flow currently exists.
- Validate the Privacy Manifest, App Privacy answers, privacy-policy URL, and Google Mobile Ads disclosures together.
- Verify Bundle ID, signing, version/build numbers, icons, screenshots, metadata, support URL, and privacy-policy URL.
- Verify fresh install and upgrade install behavior, especially SwiftData compatibility.
- Verify month/week/day navigation, event editing, all-day events, shifts, work records, statistics, holiday sync, and ad layout.
- Verify all four app languages, system-language mode, week-start settings, and light/dark appearance.
- Verify offline behavior and invalid or unavailable ICS sources.

Additional release drafts are in `Docs/AppStoreReleaseChecklist.md`, `Docs/TestFlightChecklist.md`, `Docs/PrivacyPolicyDraft.md`, and `Docs/AppStoreMetadataDraft.md`.
