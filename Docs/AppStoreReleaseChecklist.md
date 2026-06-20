# TimeNest App Store Release Checklist

> Release-preparation checklist only. It does not guarantee App Review approval. Confirm manual items in Apple Developer, App Store Connect, Xcode Organizer, and the exact submitted build.

## Repository Audit Snapshot (2026-06-20)

- [x] App target, test target, and Widget Extension are present; project shared schemes are `TimeNest` and `TimeNestWidgetExtension`, and the workspace also contains `TimeNest-Workspace`.
- [x] App Bundle ID is `com.song.TimeNest`; Widget Bundle ID is `com.song.TimeNest.widget`.
- [x] App and Widget entitlements use the same App Group: `group.com.song.TimeNest`.
- [x] Widget deep links use the registered `timenest` URL scheme.
- [x] App and Widget versions currently match at `1.0 (1)`.
- [x] `AppIcon` contains the declared iPhone, iPad, and 1024x1024 marketing icon files with matching pixel dimensions.
- [x] `ja`, `zh-Hans`, `en`, and `ko` each contain 306 unique `Localizable.strings` keys with no key-set differences; localized InfoPlist key sets also match.
- [x] `TimeNest/PrivacyInfo.xcprivacy` is included in the app resources and currently declares `UserDefaults` reason `CA92.1`, no app-declared collected data, and `NSPrivacyTracking = false`.
- [x] Current implementation has no account sign-in, cloud sync, or TimeNest-owned backend upload.
- [ ] Both checked-in Google Mobile Ads identifiers are official test IDs. Replace them with the approved production configuration, or intentionally disable ads, before submission.
- [ ] The repository currently has no ATT request, `NSUserTrackingUsageDescription`, or app-level consent flow. Decide the production advertising/privacy behavior before submission; do not infer the final App Privacy answers from the test configuration.

## 1. Developer Program and App Store Connect

- [ ] Confirm the paid Apple Developer Program enrollment has changed from Pending to Active. While pending, do not submit a duplicate enrollment, pay again, or change Apple ID.
- [ ] Confirm the App Store Connect app record uses the intended primary language and Bundle ID.
- [ ] Fill app name, subtitle, description, keywords, promotional text, release notes, categories, age rating, pricing, and availability for each supported locale.
- [ ] Fill review contact information and accurate review notes; no demo login is required because the current app has no account system.
- [ ] Confirm all required App Store agreements, tax, and banking items that apply to the account.

## 2. Bundle, Version, Signing, and Build

- [ ] Confirm `com.song.TimeNest` and `com.song.TimeNest.widget` exist under the active Developer Program team.
- [ ] Confirm the App Group `group.com.song.TimeNest` is enabled for both identifiers and provisioning profiles.
- [ ] Keep the existing app, Widget, target, and scheme names unchanged.
- [ ] Confirm the release version and increment the build number for every uploaded build; keep App and Widget versions aligned.
- [ ] Confirm Automatic Signing or distribution provisioning is valid for the intended App Store team.
- [ ] Run the final `TimeNest` Release build, archive, validation, and upload from the exact release commit.
- [ ] Confirm the uploaded build finishes App Store Connect processing without entitlement, privacy-manifest, icon, or architecture errors.

## 3. App Icon and Localizations

- [ ] Visually inspect the 1024x1024 marketing icon: no transparency, unintended padding, debug badge, or obsolete artwork.
- [ ] Confirm App Store Connect displays the expected icon after build processing.
- [ ] Recheck `ja`, `zh-Hans`, `en`, and `ko` key parity after any release-candidate change.
- [ ] Verify all four languages plus System mode on device; confirm no raw localization keys or clipped release-critical text.
- [ ] Keep user-entered event and custom shift names unchanged, and keep holiday names region-native.

## 4. Privacy, Permissions, Ads, and ATT

- [x] Record the public Privacy Policy URL in release documents: https://songlabs.github.io/timenest/privacy.html
- [ ] Confirm the published privacy policy matches the submitted build, including its effective date, support contact, and final advertising disclosure.
- [x] Prepare `Docs/AppPrivacyAnswersDraft.md` covering local storage, Widget App Group sharing, public ICS requests, Google Mobile Ads uncertainty, and ATT decision points.
- [ ] Complete App Store App Privacy answers using the submitted Google Mobile Ads SDK/configuration and the app's public ICS requests, local notifications, local storage, and Widget App Group behavior.
- [ ] Review the archive privacy report and all SDK privacy manifests. Confirm the app-level `PrivacyInfo.xcprivacy` and App Store answers remain accurate for the submitted build.
- [ ] Decide whether production ads access IDFA or otherwise meet Apple's tracking definition. If ATT is required, add the authorization flow and localized purpose text in a separate, explicitly scoped change before loading ads.
- [ ] If ATT is not used, confirm the production ad request configuration and App Privacy answers accurately reflect non-ATT behavior.
- [ ] Review whether a Google UMP/regional consent flow is required for the intended distribution regions. The package is resolved transitively, but the current app does not invoke a consent flow.
- [ ] Review Google's current `SKAdNetworkItems` guidance against the final ad configuration; the current `Info.plist` has no `SKAdNetworkItems` entry.
- [ ] Confirm production App ID and banner unit ID are not Google test IDs; never commit or guess unapproved identifiers.
- [ ] Reconfirm that the current app has no user-facing remove-ads purchase flow; do not advertise one.

## 5. URLs, Metadata, and Screenshots

- [x] Record the public Support URL in release documents: https://songlabs.github.io/timenest/support.html
- [ ] Confirm both public URLs remain reachable without authentication and accurately describe the submitted build.
- [x] Replace the URL placeholders in `Docs/AppStoreMetadataDraft.md` with the public Privacy Policy and Support URLs.
- [ ] Confirm metadata claims match the submitted build and do not describe login, cloud sync, sharing, analytics, or remove-ads features as implemented.
- [x] Prepare the six-shot capture outline in `Docs/ScreenshotPlan.md`.
- [ ] Prepare required iPhone screenshot sizes for each App Store locale selected in App Store Connect.
- [ ] Capture: month view, week view, day view, event create/edit, holiday subscriptions, shift input/work statistics, and language/settings.
- [ ] Add a Widget screenshot only if it is part of the release messaging and accurately reflects the submitted Widget.
- [ ] Exclude test ads, placeholder URLs, debug text, simulator chrome, personal schedule data, and unimplemented features from screenshots.

## 6. Export Compliance

- [x] Prepare the current technical inventory and manual-answer notes in `Docs/ExportComplianceNotes.md` without changing InfoPlist.
- [ ] Review the exact final archive and answer App Store Connect's current export-compliance questions manually.
- [ ] Confirm whether an exemption or supporting documentation applies to standard HTTPS and embedded third-party SDK behavior; do not guess or change `ITSAppUsesNonExemptEncryption` without that review.

## 7. Device and TestFlight Gate

- [ ] Install the release candidate on a physical device and confirm launch, foreground/background return, and local data persistence.
- [ ] Confirm notification permission allow/deny behavior when saving an event with a reminder.
- [ ] Complete `Docs/TestFlightChecklist.md` on the exact candidate build.
- [ ] Complete at least one TestFlight internal-test pass and record device, iOS version, app version/build, language, network state, and result.
- [ ] Confirm fresh-install and upgrade-install behavior, including SwiftData compatibility and Widget refresh.
- [ ] Resolve release-blocking crashes, upload errors, missing metadata, and privacy-answer mismatches before submission.
