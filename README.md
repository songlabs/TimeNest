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

## Unit Tests

The `TimeNestTests` target covers calendar grid generation, localization resource parity, holiday-name normalization and ICS parsing, event scheduling, shift settings, timeline calculations, and work-statistics rules. Run the full unit-test target with:

```bash
xcodebuild \
  -scheme TimeNest \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  test
```

Use an installed simulator destination when the example runtime is unavailable. Do not replace product-rule assertions with weaker expectations to make a failing test pass; first confirm whether the implementation or an outdated test fixture is wrong.

## Project Layout

```text
TimeNest/
  App/                 App entry point and root view
  Application/         Calendar, event, holiday, reminder, subscription, and import/export use cases
  Domain/              Calendar/event models and product rules without UI ownership
  Infrastructure/      SwiftData repositories, notifications, ICS, holiday cache, ads, and adapters
  Presentation/        Calendar, event editor, day detail, settings, statistics, and ad views
  Resources/           App icons and localized strings
  Shared/              Date, localization, notification, style, and theme utilities
Tests/TimeNestTests/    Unit-test sources
Docs/                  App Store, TestFlight, metadata, and privacy drafts
Project.swift          Tuist project definition
TimeNest.xcodeproj/     Checked-in Xcode project used by the shared scheme
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

The localization parity tests require the `ja`, `zh-Hans`, `en`, and `ko` files to contain the same unique key set, and require every `LocalizedString` enum case to exist in the resources. Date, month, and weekday text should use `LocalizationManager` so the in-app language and week-start setting remain consistent.

## Holiday Subscriptions

- The app provides sources for Japan, China, Korea, and the United States, with at most two subscriptions enabled at once.
- Settings supports enabling or disabling a region, manual refresh, recommended or custom HTTPS source URLs, restoring the default URL, and testing whether the current URL downloads and parses as ICS.
- Enabled subscriptions are cached locally. Settings may attempt a background refresh when cached subscription data is stale; refresh failure must not turn calendar display into a network-only path.
- `ICSParsingService` preserves provider data, while `HolidayNameLocalizer` maps known aliases to the holiday region's native display name.
- Source limits, test behavior, refresh notifications, cache replacement, and error handling are product behavior. Keep them covered when changing the subscription manager or source editor.

## Local-First Data

Calendar events, shifts, work records, settings, and holiday choices are stored on the device. SwiftData repositories are the production event/reminder storage, and downloaded holiday data is a replaceable local cache. Network access is limited to explicit or scheduled holiday-source refreshes and enabled ad SDK behavior; calendar editing and existing local data must not depend on a successful request.

## Data And Privacy

- Events and work information are stored locally with SwiftData.
- Display settings and holiday-subscription choices are stored locally in app preferences.
- Downloaded holiday data is cached on the device.
- Holiday synchronization sends HTTPS requests to the public ICS provider selected in Settings.
- Banner ads use Google Mobile Ads when `AdConfiguration.isEnabled` is `true`; SDK behavior and App Store privacy disclosures must be reviewed against the production configuration.
- The app has no account sign-in or cloud synchronization in the current implementation.

Uninstalling the app removes its local container under normal iOS behavior. Existing SwiftData entities and decoding compatibility must be treated as user-data migration code and should not be removed as ordinary cleanup.

## Maintenance Notes

- Reuse the shared calendar header, bottom toolbar, modal surface, theme, localization, and timeline helpers before adding screen-local variants.
- Keep shift events separate from clock-in/clock-out work records. Preserve the one-shift-per-day rule, work-session pairing, overnight clock-out handling, rest time, transport fee, hourly rate, and statistics calculations.
- Avoid `DateFormatter`, repeated filtering/sorting, or holiday lookups inside SwiftUI rendering loops. Prefer `LocalizationManager`'s formatter cache and pre-group data at the use-case or view-model boundary.
- Keep `Project.swift` and the checked-in Xcode project aligned when adding or removing source files. Do not change Bundle ID, signing, targets, schemes, assets, or package dependencies as part of routine cleanup.
- Before merging calendar or settings changes, run the full unit-test command and a simulator build, verify all four localization key sets, and inspect month/week/day, event editing, holiday subscription, shift settings, and work statistics references.

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

Release-preparation documents:

- [Public privacy policy](https://songlabs.github.io/timenest/privacy.html)
- [Public support page](https://songlabs.github.io/timenest/support.html)
- [App Store release checklist](Docs/AppStoreReleaseChecklist.md)
- [TestFlight checklist](Docs/TestFlightChecklist.md)
- [Privacy policy draft](Docs/PrivacyPolicyDraft.md)
- [App Store metadata draft](Docs/AppStoreMetadataDraft.md)
- [App Review notes draft](Docs/AppReviewNotesDraft.md)
- [TestFlight submission notes](Docs/TestFlightSubmissionNotes.md)
- [App Privacy answers draft](Docs/AppPrivacyAnswersDraft.md)
- [Export compliance notes](Docs/ExportComplianceNotes.md)
- [Screenshot plan](Docs/ScreenshotPlan.md)
