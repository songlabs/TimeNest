# TimeNest App Store Release Checklist

> Release-preparation checklist only. It does not guarantee App Review approval. Confirm manual items in Apple Developer, App Store Connect, Xcode Organizer, and the exact submitted build.

## Repository Audit Snapshot (2026-06-23)

- [x] App target, test target, and Widget Extension are present; project shared schemes are `TimeNest` and `TimeNestWidgetExtension`, and the workspace also contains `TimeNest-Workspace`.
- [x] App Bundle ID is `com.song.TimeNest`; Widget Bundle ID is `com.song.TimeNest.TimeNestWidgetExtension`.
- [x] App and Widget entitlements use the same App Group: `group.com.songlabs.timenest`.
- [x] Widget deep links use the registered `timenest` URL scheme.
- [x] App and Widget versions currently match at `1.0 (1)`.
- [x] `AppIcon` contains the declared iPhone, iPad, and 1024x1024 marketing icon files with matching pixel dimensions.
- [x] `ja`, `zh-Hans`, `en`, and `ko` each contain 314 unique `Localizable.strings` keys with no key-set differences; localized InfoPlist key sets also match and include `NSUserTrackingUsageDescription`.
- [x] `TimeNest/PrivacyInfo.xcprivacy` is included in the app resources and currently declares `UserDefaults` reason `CA92.1`, no app-declared collected data, and `NSPrivacyTracking = false`.
- [x] Current implementation has no account sign-in, cloud sync, or TimeNest-owned backend upload.
- [x] Debug and simulator builds use Google's official test IDs. Release device/archive builds are ad-enabled and cannot be built with disabled ads, empty IDs, placeholders, malformed IDs, or Google's test IDs.
- [x] Both Release build-setting sources use the approved production AdMob App ID and Banner Unit ID.
- [x] Google UMP now updates consent once per launch and gates Mobile Ads initialization and banner loading on `canRequestAds`. Publisher Privacy Treatment disables ad personalization.
- [x] ATT is requested after the UMP consent flow and before Mobile Ads initialization/banner loading. `NSUserTrackingUsageDescription` is localized in all four supported languages.

## 1. Developer Program and App Store Connect

- [ ] Confirm the paid Apple Developer Program membership, agreements, tax, and banking status are active before submission.
- [ ] Confirm the App Store Connect app record uses the intended primary language and Bundle ID.
- [ ] Fill app name, subtitle, description, keywords, promotional text, release notes, categories, age rating, pricing, and availability for each supported locale.
- [x] Prepare Japanese-primary and `zh-Hans` / `en` / `ko` copy candidates in `Docs/AppStoreMetadataDraft.md`.
- [x] Prepare the copy candidate and manual configuration TODOs in `Docs/AppReviewNotesDraft.md`.
- [ ] Fill review contact information and accurate review notes from the exact submitted build; no demo login is required because the current app has no account system.
- [ ] Confirm all required App Store agreements, tax, and banking items that apply to the account.

## 2. Bundle, Version, Signing, and Build

- [ ] Confirm `com.song.TimeNest` and `com.song.TimeNest.TimeNestWidgetExtension` exist under the active Developer Program team.
- [ ] Confirm the App Group `group.com.songlabs.timenest` is enabled for both identifiers and provisioning profiles.
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
- [x] Expose the public Privacy Policy from Settings > Support > Privacy Policy using the system URL-opening flow.
- [ ] Confirm the published privacy policy matches the submitted build, including its effective date, support contact, and final advertising disclosure.
- [x] Prepare `Docs/AppPrivacyAnswersDraft.md` covering local storage, Widget App Group sharing, public ICS requests, Google Mobile Ads uncertainty, and ATT decision points.
- [ ] Submission gate: complete App Store Connect App Privacy answers using the submitted Google Mobile Ads SDK/configuration and the app's public ICS requests, local notifications, local storage, and Widget App Group behavior.
- [ ] Review the archive privacy report and all SDK privacy manifests. Confirm the app-level `PrivacyInfo.xcprivacy` and App Store answers remain accurate for the submitted build.
- [x] Current code requests ATT after UMP completes and before Mobile Ads initialization. Authorized, denied, and restricted outcomes all preserve app access; denied/restricted outcomes may continue without IDFA when UMP permits ads.
- [ ] Confirm the submitted production configuration, App Privacy Tracking answer, public privacy policy, archive privacy report, and any required tracking-domain declaration all match the ATT-enabled behavior.
- [x] Google UMP consent flow is centralized in the Ads layer. Help shows a localized privacy-options action only when UMP reports that an entry point is required.
- [ ] Configure the intended GDPR/US-state privacy messages in the AdMob console for the production App ID and verify them on physical devices in applicable regions.
- [x] `Info.plist` includes the `SKAdNetworkItems` list from Google's iOS guidance checked on 2026-06-23.
- [ ] Confirm `TIMENEST_ADS_ENABLED=YES`, `TIMENEST_ADMOB_APP_ID` is the production App ID, and `TIMENEST_ADMOB_BANNER_UNIT_ID` is the production Banner Unit ID in the exact archive build settings.
- [ ] Confirm the Release device/archive validation script succeeds and the processed archive `Info.plist` contains the production `GADApplicationIdentifier`, never Google's test App ID or a placeholder.
- [ ] Reconfirm that the current app has no user-facing remove-ads purchase flow; do not advertise one.
- [x] Record Google Mobile Ads 13.5.0 and Google User Messaging Platform 3.1.0 notices in `Docs/ThirdPartyNotices.md`.
- [x] Expose the two wrapper attributions and Apache-2.0 license type through Settings > Third-party Licenses.
- [ ] On physical devices, verify fresh-install UMP consent followed by localized ATT, ATT authorized/denied/restricted behavior, returning-user consent, required privacy-options presentation, denied/no-consent layout stability, and production banner loading.

## 5. URLs, Metadata, and Screenshots

- [x] Record the public Support URL in release documents: https://songlabs.github.io/timenest/support.html
- [ ] Confirm both public URLs remain reachable without authentication and accurately describe the submitted build.
- [ ] Update the published privacy policy so the advertising disclosure is final rather than conditional and clearly covers third-party data retention/deletion and how users can withdraw consent or reopen required privacy options.
- [x] Replace the URL placeholders in `Docs/AppStoreMetadataDraft.md` with the public Privacy Policy and Support URLs.
- [ ] Paste and recheck the final localized metadata against the exact submitted build and App Store Connect field limits.
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
