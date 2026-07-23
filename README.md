# TimeNest

TimeNest is a local-first iOS calendar app built with Swift and SwiftUI. It combines month, week, and day schedule views with shift and work-time records, public-holiday subscriptions, and an in-app language setting. User-created calendar data is stored on the device with SwiftData.

## Features

- Month, week, and day calendar views with shared navigation and footer controls.
- Create, edit, and delete timed or all-day events.
- Add memo text manually or by voice on supported devices and languages.
- Shift templates, shift entry, same-day shift replacement, and shift deletion.
- Clock-in, clock-out, rest time, transport fee, and hourly-rate records.
- Work statistics for a selected date range.
- Public-holiday subscriptions and ICS synchronization for Japan, China, Taiwan, Korea, and the United States.
- Optional CloudKit calendar sharing with read-only recipients. Events, shifts, and work records in a shared calendar are synchronized automatically; memos, notifications, voice-input content, hourly rates, pay, and transport fees are not shared.
- Japanese, Simplified Chinese, Traditional Chinese, English, and Korean UI resources, plus a system-language mode.
- Light, dark, and system appearance settings.
- A calendar banner-ad container backed by Google Mobile Ads.

The first release is ad-supported and includes a one-time Apple In-App Purchase to remove ads. Unpurchased users see banner ads after the required consent flow permits ad requests; purchased users do not create or reserve space for the banner. Debug builds use Google's official test identifiers. Release builds require advertising to be enabled with approved production App and Banner IDs; missing, placeholder, malformed, or Google test IDs fail the Release build.

## Shared Calendars

- Open the calendar chooser from the icon at the top left. TimeNest displays either My Calendar or one selected shared calendar; the checkmark identifies the current selection.
- Adding an event or work record from a displayed writable calendar automatically assigns it to that calendar, without asking for the calendar again. Editing keeps the entry in its original calendar. TimeNest currently displays one calendar at a time and has no aggregate-calendar add flow.
- Creating, renaming, inviting people to, accepting, refreshing, stopping, leaving, or deleting a shared calendar requires access to the user's Apple iCloud account and CloudKit. A recipient device must also be able to use iCloud to accept an invitation.
- Recipients have read-only access. They can view shared events, shifts, and work records but cannot create, edit, move, or delete the owner's shared content. If they try to add an entry, TimeNest asks them to switch to a calendar they can edit.
- Events, shifts, and work records assigned to an owned shared calendar are currently synchronized automatically. The current implementation does not expose per-category sharing switches.
- Event titles and times, shift display data, and work-record clock-in, clock-out, and break times may enter the shared zone. Memos, reminders and notifications, voice-input content, hourly rates, pay, transport costs, shift-template settings, app settings, and Remove Ads purchase state do not.
- Holidays are not synchronized through CloudKit. A shared calendar uses the recipient device's enabled holiday regions and local holiday cache.
- When an owner stops sharing or deletes a shared calendar, recipients lose access. Leaving a received share removes it from that recipient's TimeNest data without changing the owner's calendar. CloudKit changes may require a short refresh before they appear.

## Technology

- Swift 5.9
- SwiftUI
- SwiftData local persistence
- iOS 17.0 or later
- Tuist project description with a checked-in Xcode project/workspace
- Google Mobile Ads and Google User Messaging Platform through Swift Package Manager
- Apple CloudKit calendar sharing

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

## Release Advertising Configuration

The checked-in Xcode project and `Project.swift` define the same three build settings:

- `TIMENEST_ADS_ENABLED`: `YES` for both Debug and Release. The first release must support ads for users who have not purchased Remove Ads.
- `TIMENEST_ADMOB_APP_ID`: Google's official test App ID in Debug and simulator builds; Release device/archive builds use the production App ID configured in `Project.swift` and the checked-in Xcode project.
- `TIMENEST_ADMOB_BANNER_UNIT_ID`: Google's official test Banner Unit ID in Debug and simulator builds; Release device/archive builds use the production Banner Unit ID configured in `Project.swift` and the checked-in Xcode project.

`TimeNest/Info.plist` expands `GADApplicationIdentifier` and the banner setting from these values. Release device/archive values must be the approved production IDs, while simulator overrides keep development builds on Google's official test IDs. `Scripts/validate_admob_release_config.sh` rejects a production Release build when advertising is disabled or either identifier is empty, a placeholder, malformed, or a Google test ID. `AdConfiguration` repeats the validation at startup as defense in depth. Keep `Project.swift` and `TimeNest.xcodeproj/project.pbxproj` aligned when changing the two production values.

The Remove Ads StoreKit product ID is `com.song.TimeNest.remove_ads`; keep `AdConfiguration.removeAdsProductID`, `TimeNest.storekit`, App Store Connect, and release documents aligned when reviewing IAP.

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

UI strings are maintained in all five `Localizable.strings` files:

- `TimeNest/Resources/ja.lproj/Localizable.strings`
- `TimeNest/Resources/zh-Hans.lproj/Localizable.strings`
- `TimeNest/Resources/zh-Hant.lproj/Localizable.strings`
- `TimeNest/Resources/en.lproj/Localizable.strings`
- `TimeNest/Resources/ko.lproj/Localizable.strings`

When adding or changing UI text:

1. Reuse an existing `LocalizedString` key when it has the same meaning.
2. Add every new key to `Localizable.swift` and all five language files in the same change.
3. Resolve app UI text through `LocalizationManager` so the in-app language selection is respected.
4. Do not translate user-entered event titles or customized shift names.
5. Keep holiday display names region-native: Japanese holidays in Japanese, mainland China holidays in Simplified Chinese, Taiwan holidays in Traditional Chinese, Korean holidays in Korean, and US holidays in English.

The localization parity tests require the `ja`, `zh-Hans`, `zh-Hant`, `en`, and `ko` files to contain the same unique key set, and require every `LocalizedString` enum case to exist in the resources. Date, month, and weekday text should use `LocalizationManager` so the in-app language and week-start setting remain consistent.

## Holiday Subscriptions

- The app provides sources for Japan, China, Taiwan, Korea, and the United States, with at most two subscriptions enabled at once.
- Settings supports enabling or disabling a region, manual refresh, recommended or custom HTTPS source URLs, restoring the default URL, and testing whether the current URL downloads and parses as ICS.
- Enabled subscriptions are cached locally. Settings may attempt a background refresh when cached subscription data is stale; refresh failure must not turn calendar display into a network-only path.
- `ICSParsingService` preserves provider data, while `HolidayNameLocalizer` maps known aliases to the holiday region's native display name.
- Source limits, test behavior, refresh notifications, cache replacement, and error handling are product behavior. Keep them covered when changing the subscription manager or source editor.

## Local-First Data

Calendar events, shifts, work records, settings, and holiday choices are stored on the device by default. SwiftData repositories are the production event/reminder storage and use `TimeNest.store` under the `group.com.songlabs.timenest` App Group container. The Widget does not open that SwiftData store directly; it reads a separate `widget-snapshot.json` snapshot in the same App Group. Downloaded holiday data is a replaceable local cache. Network access is used for optional CloudKit calendar sharing, explicit or scheduled holiday-source refreshes, StoreKit, and enabled ad SDK behavior; local calendar editing and existing local data must not depend on a successful request.

`v1.0.0` stored the same SwiftData schema in the app sandbox's Application Support directory. Before the current App Group container enters normal use, `LegacyStoreMigrator` performs a one-time model-level import only when the destination has no events or reminders. It preserves the legacy store, never merges into or overwrites a populated destination, validates migrated counts, and uses both destination state and a marker to prevent repeated import. Temporary-store regression tests cover the migration path; a real App Store `v1.0.0` physical-device upgrade remains a required release check.

## Data And Privacy

- Events and work information are stored locally with SwiftData.
- Display settings and holiday-subscription choices are stored locally in app preferences.
- Downloaded holiday data is cached on the device.
- Holiday synchronization sends HTTPS requests to the public ICS provider selected in Settings.
- Voice memo input uses the microphone and Apple's Speech framework only when the user starts voice input in the memo field; recognized text is inserted into the local memo.
- Banner ads use Google Mobile Ads only after Google UMP reports `canRequestAds == true` and the ATT decision completes. Ad personalization is disabled through Publisher Privacy Treatment; denying ATT keeps the calendar usable and permits non-IDFA ad requests when UMP allows ads.
- Remove Ads is a one-time Apple In-App Purchase handled by StoreKit. TimeNest does not collect or store payment card details, and purchase restoration uses Apple transaction entitlements.
- The app has no TimeNest account, developer-operated backend, or general-purpose cloud sync. Optional shared calendars use the user's Apple iCloud account and CloudKit; recipients are read-only and only the selected event, shift, and work-record fields enter the shared zone.

Uninstalling the app removes its local container under normal iOS behavior. Existing SwiftData entities and decoding compatibility must be treated as user-data migration code and should not be removed as ordinary cleanup.

## Maintenance Notes

- Reuse the shared calendar header, bottom toolbar, modal surface, theme, localization, and timeline helpers before adding screen-local variants.
- Keep shift events separate from clock-in/clock-out work records. Preserve the one-shift-per-day rule, work-session pairing, overnight clock-out handling, rest time, transport fee, hourly rate, and statistics calculations.
- Avoid `DateFormatter`, repeated filtering/sorting, or holiday lookups inside SwiftUI rendering loops. Prefer `LocalizationManager`'s formatter cache and pre-group data at the use-case or view-model boundary.
- Keep `Project.swift` and the checked-in Xcode project aligned when adding or removing source files. Do not change Bundle ID, signing, targets, schemes, assets, or package dependencies as part of routine cleanup.
- Before merging calendar or settings changes, run the full unit-test command and a simulator build, verify all five localization key sets, and inspect month/week/day, event editing, holiday subscription, shift settings, and work statistics references.

## App Store Release Checklist

Before submission, confirm:

- Confirm both Release device/archive identifiers use the approved production AdMob App ID and Banner Unit ID; the first release must not disable ads for unpurchased users.
- Confirm the one-time Remove Ads In-App Purchase and restore flow match the submitted build and App Store Connect product status before mentioning them in metadata.
- Configure and verify the required consent messages and privacy-options behavior in the AdMob console.
- Verify the five localized ATT purpose strings and authorized/denied paths on physical devices.
- Validate the Privacy Manifest, App Privacy answers, privacy-policy URL, and Google Mobile Ads disclosures together.
- Verify Bundle ID, signing, version/build numbers, icons, screenshots, metadata, support URL, and privacy-policy URL.
- Verify a physical-device App Store `v1.0.0` upgrade preserves schedules, shifts, work records, reminders, and Widget refresh. Local temporary-store tests are not a substitute for this check.
- Verify month/week/day navigation, event editing, memo voice input permissions, all-day events, shifts, work records, statistics, holiday sync, and ad layout.
- Verify all five app languages, system-language mode, week-start settings, and light/dark appearance.
- Verify offline behavior and invalid or unavailable ICS sources.
- Verify CloudKit sharing on two physical devices, including invitation acceptance, recipient read-only behavior, automatic event/shift/work-record synchronization, name updates, stopping/leaving a share, recipient-local holidays, and excluded private fields.

Release-preparation documents:

- [Public privacy policy](https://songlabs.github.io/timenest/privacy.html)
- [Public support page](https://songlabs.github.io/timenest/support.html)
- [App Store release checklist](Docs/AppStoreReleaseChecklist.md)
- [TestFlight checklist](Docs/TestFlightChecklist.md)
- [Privacy policy draft](Docs/PrivacyPolicyDraft.md)
- [Public support page draft](Docs/SupportPageDraft.md)
- [App Store metadata draft](Docs/AppStoreMetadataDraft.md)
- [App Review notes draft](Docs/AppReviewNotesDraft.md)
- [TestFlight submission notes](Docs/TestFlightSubmissionNotes.md)
- [App Privacy answers draft](Docs/AppPrivacyAnswersDraft.md)
- [Export compliance notes](Docs/ExportComplianceNotes.md)
- [Screenshot plan](Docs/ScreenshotPlan.md)
- [Third-party notices](Docs/ThirdPartyNotices.md)
