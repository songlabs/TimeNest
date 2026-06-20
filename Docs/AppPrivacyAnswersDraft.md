# TimeNest App Privacy Answers Draft

> Submission-preparation draft only. This is not a completed App Store Connect declaration. Re-answer the current questionnaire against the exact submitted build, production Google Mobile Ads configuration, enabled SDK features, consent behavior, and Apple's then-current definitions.

## Public URLs

- Privacy Policy URL: https://songlabs.github.io/timenest/privacy.html
- Support URL: https://songlabs.github.io/timenest/support.html

## Confirmed Current Data Flows

- User-created schedules, notes, shifts, and work records are stored locally with SwiftData by default.
- The SwiftData production configuration does not use CloudKit.
- TimeNest currently has no account system, sign-in, developer-operated cloud synchronization, or TimeNest-owned backend upload.
- App settings, holiday-subscription choices, subscription URLs, and downloaded holiday cache data are stored locally.
- The app and Widget share a calendar snapshot through the App Group on the same device. This is local App-to-Widget data sharing, not cloud synchronization or a backend upload.
- When a user enables, tests, or refreshes a holiday subscription, the app sends an HTTPS request to the public ICS provider selected by the user. That provider may receive network information such as an IP address and request metadata under its own policy.
- Google Mobile Ads is integrated and currently enabled in the repository. The checked-in identifiers are test identifiers and are not the final production advertising configuration.
- The app currently has no user-facing remove-ads purchase flow.

## App Store Connect Answering Draft

### Data Collection Overview

- User-created calendar, shift, and work-record content: locally stored by default and not uploaded to a TimeNest-owned server in the current implementation.
- Widget snapshot: shared only within the on-device App Group for Widget display.
- Holiday ICS requests: sent to a user-selected third-party public provider; evaluate the questionnaire using Apple's current definition of collection and the provider interaction in the submitted build.
- Google Mobile Ads data: **TODO - final answer required.** Review the exact production SDK version and configuration against Google's current App Store data-disclosure documentation and the archive privacy report.

Do not answer the overall "Data Not Collected" question until the advertising and third-party SDK review is complete. The local-first product data flow alone is not enough to determine the final answer for the whole app.

### Candidate Data Types Requiring Final Ad Review

The Google Mobile Ads SDK may require disclosure of data types such as identifiers, usage data, diagnostics, coarse location inferred from IP address, or advertising data. This list is not a final declaration.

- **TODO:** Confirm every collected data type present in the submitted build.
- **TODO:** For each type, confirm whether it is linked to the user.
- **TODO:** For each type, select the applicable purpose, such as third-party advertising, analytics, or app functionality.
- **TODO:** Confirm whether any data is used for tracking under Apple's current definition.
- **TODO:** Confirm whether regional consent or Google UMP behavior changes the declared processing.

### Tracking and ATT

- The current repository does not request ATT authorization and does not contain `NSUserTrackingUsageDescription`.
- **TODO:** Decide whether the final production advertising configuration accesses IDFA or otherwise constitutes tracking under Apple's definition.
- **TODO:** If tracking is used, implement and validate the required ATT flow in a separate explicitly scoped change before submission, then update the privacy policy, Privacy Manifest, and App Store answers.
- **TODO:** If tracking is not used, verify that the production ad request configuration, SDK behavior, privacy policy, Privacy Manifest, and App Store answers consistently reflect that decision.

## Final Manual Verification

- [ ] Compare the exact archived build's privacy report and embedded SDK privacy manifests with this draft.
- [ ] Confirm the production Google Mobile Ads App ID, banner unit ID, request configuration, and optional SDK features.
- [ ] Confirm ATT and regional consent decisions.
- [ ] Complete the App Store Connect App Privacy questionnaire manually using its current wording.
- [ ] Confirm the submitted answers match the published privacy policy.
