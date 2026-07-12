# TimeNest App Privacy Answers Draft

> Submission-preparation draft only. This is not a completed App Store Connect declaration. Re-answer the current questionnaire against the exact submitted build, production Google Mobile Ads configuration, enabled SDK features, consent behavior, and Apple's then-current definitions.

## Public URLs

- Privacy Policy URL: https://songlabs.github.io/timenest/privacy.html
- Support URL: https://songlabs.github.io/timenest/support.html
- Publication status (2026-07-12): the repository does not contain the public HTML sources, so the CloudKit updates in `PrivacyPolicyDraft.md` and `SupportPageDraft.md` still require manual publication and URL verification.

## Confirmed Current Data Flows

- User-created schedules, notes, shifts, and work records are stored locally with SwiftData by default.
- A one-time local-only migration preserves eligible `v1.0.0` SwiftData records when moving from the app sandbox store to the App Group store. It does not upload data, delete the legacy store, or merge into a populated destination.
- The SwiftData production configuration does not use CloudKit.
- TimeNest currently has no account system, sign-in, developer-operated cloud synchronization, or TimeNest-owned backend upload.
- Optional shared calendars use Apple iCloud/CloudKit. The owner selects whether events, shifts, and work records enter the shared zone, and recipients are read-only. Shared records exclude memo text, notifications, voice content, hourly rates, pay, transport fees, templates, purchase/ad state, device information, app settings, Widget-private data, and holiday-subscription internals.
- App settings, holiday-subscription choices, subscription URLs, and downloaded holiday cache data are stored locally.
- The app and Widget share a calendar snapshot through the App Group on the same device. This is local App-to-Widget data sharing, not cloud synchronization or a backend upload.
- When a user enables, tests, or refreshes a holiday subscription, the app sends an HTTPS request to the public ICS provider selected by the user. That provider may receive network information such as an IP address and request metadata under its own policy.
- Google Mobile Ads and Google UMP are integrated. Unpurchased users see ads when UMP permits ad requests. Debug and simulator builds use official test identifiers, while Release device/archive builds use approved production identifiers and fail build validation when they are missing or invalid.
- Ads remain gated by UMP `canRequestAds`. After the UMP update and any required consent form complete, the app requests ATT when the status is not determined, then starts Mobile Ads. Publisher Privacy Treatment disables ad personalization.
- If ATT is denied or restricted, the app remains usable and may continue requesting ads without IDFA when UMP permits ad requests. Banner loading is separately gated until the ATT decision completes.
- The embedded Google Mobile Ads 13.5.0 privacy manifest declares linked coarse location, advertising data, product interaction, and Device ID. It marks Device ID as used for tracking. The Google UMP 3.1.0 privacy manifest also declares coarse location, performance data, and product interaction for app functionality.
- The app offers a one-time Remove Ads In-App Purchase through Apple StoreKit. TimeNest does not collect or store payment card details, and purchase restoration uses Apple's transaction entitlements.
- Settings exposes the published Privacy Policy URL through the system URL-opening flow.

## App Store Connect Answering Draft

### Data Collection Overview

- User-created calendar, shift, and work-record content: locally stored by default and not uploaded to a TimeNest-owned server in the current implementation.
- Widget snapshot: shared only within the on-device App Group for Widget display.
- CloudKit shared calendars: uploaded to and synchronized by Apple iCloud only when the user enables sharing; evaluate this transfer and Apple's role against the current App Privacy questionnaire and published policy.
- Holiday ICS requests: sent to a user-selected third-party public provider; evaluate the questionnaire using Apple's current definition of collection and the provider interaction in the submitted build.
- Google Mobile Ads data: **TODO - final answer required.** Review the exact production SDK version and configuration against Google's current App Store data-disclosure documentation and the archive privacy report.

Do not answer the overall "Data Not Collected" question until the advertising and third-party SDK review is complete. The local-first product data flow alone is not enough to determine the final answer for the whole app.

### Candidate Data Types Requiring Final Ad Review

The embedded SDK privacy manifests and Google's current disclosure guidance identify data types including Device ID, coarse location, advertising data, product interaction, crash data, performance data, and other diagnostic data. This remains a candidate list until it is checked against the exact production configuration and archive privacy report.

- **TODO:** Confirm every collected data type present in the submitted build.
- **TODO:** For each type, confirm whether it is linked to the user.
- **TODO:** For each type, select the applicable purpose, such as third-party advertising, analytics, or app functionality.
- **TODO:** Confirm whether any data is used for tracking under Apple's current definition.
- **TODO:** Confirm the production AdMob console messages, regional UMP behavior, and privacy-options entry point against the submitted build.

### Tracking and ATT

- The app includes `NSUserTrackingUsageDescription` in Japanese, Simplified Chinese, Traditional Chinese, English, and Korean and calls ATT only after the UMP consent flow completes, before Mobile Ads starts or a banner request is sent.
- The ATT result does not gate access to calendar functionality. A denied or restricted result still allows non-IDFA ad requests when UMP `canRequestAds` is true.
- **TODO:** Complete App Store Connect Tracking and App Privacy answers for the exact submitted SDK/configuration. If Device ID is declared as used for tracking, the Tracking answer, privacy policy, archive privacy report, and ATT implementation must remain consistent.
- **TODO:** Review the final archive's aggregated privacy manifest, including whether `NSPrivacyTracking` and actual tracking domains require an app-level declaration. Do not add guessed domains.

## Final Manual Verification

- [ ] Compare the exact archived build's privacy report and embedded SDK privacy manifests with this draft.
- [ ] Confirm the production Google Mobile Ads App ID, banner unit ID, request configuration, and optional SDK features.
- [ ] Confirm the exact Release build has `TIMENEST_ADS_ENABLED=YES` and its processed `Info.plist` contains the production App ID.
- [ ] Verify the localized ATT prompt and authorized/denied/restricted paths on physical devices after the UMP flow.
- [ ] Complete the App Store Connect App Privacy questionnaire manually using its current wording.
- [ ] Confirm Settings > Support > Privacy Policy opens https://songlabs.github.io/timenest/privacy.html in the exact release candidate.
- [ ] Publish the CloudKit-sharing updates from `Docs/PrivacyPolicyDraft.md` and `Docs/SupportPageDraft.md`; the repository change alone does not update either public URL.
- [ ] Confirm the submitted answers match the published privacy policy.
