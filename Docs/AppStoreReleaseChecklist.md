# TimeNest App Store Release Checklist

> Release-preparation checklist only. It does not guarantee App Review approval. Confirm every item in Apple Developer, App Store Connect, Xcode Organizer, and the submitted build before release.

## 1. App Store Connect Items

- Create or confirm the App Store Connect app record.
- Confirm app name, subtitle, description, keywords, promotional text, release notes, category, and age rating in each supported locale.
- Prepare iPhone screenshots for required display sizes.
- Prepare Support URL and Privacy Policy URL. Do not submit placeholder URLs.
- Confirm review contact information and demo/review notes.
- Confirm pricing and availability.
- Confirm TestFlight internal and external tester groups.

## 2. Bundle ID / Signing / Archive / Upload

- Bundle ID: `com.song.TimeNest`.
- Confirm the Bundle ID exists in Apple Developer.
- Confirm capabilities in Apple Developer match the app target. Do not enable unused capabilities.
- Confirm Automatic Signing or manual provisioning profile is valid for App Store distribution.
- Confirm Team ID and certificate are correct in Xcode.
- Increment `CFBundleShortVersionString` and `CFBundleVersion` for each upload.
- Run a Release archive in Xcode Organizer.
- Validate the archive before upload.
- Upload to App Store Connect and confirm processing completes successfully.

## 3. Privacy Manifest

- Confirm `TimeNest/PrivacyInfo.xcprivacy` is included in the app target.
- Current repository implementation includes Google Mobile Ads for a calendar banner. It does not include account sign-in or cloud sync.
- Current repository implementation uses local storage and `UserDefaults` for local settings and state.
- Confirm the submitted Google Mobile Ads SDK version contributes all required privacy-manifest declarations, and review the app's own manifest against the production ad configuration.
- If future builds add cloud sync, push notifications, accounts, crash reporting, or analytics, update the Privacy Manifest before upload.

## 4. App Privacy Labels

Do not finalize these answers until the production Google Mobile Ads configuration and consent flow have been reviewed:

- Tracking: confirm from the submitted ad configuration and Google Mobile Ads data-use documentation.
- Data Used to Track You: confirm from the submitted ad configuration.
- Data Linked to You / Data Not Linked to You: include every category used by the advertising SDK or app.
- Local-only data: user-created schedules, settings, holiday subscription URLs, and cached holiday data are stored locally by default.
- Network access: holiday subscription sync accesses public HTTPS ICS URLs selected or confirmed by the user.
- Advertising network access: the calendar banner can contact Google Mobile Ads when ads are enabled.

Reconfirm these labels if any implementation changes before submission.

## 5. Screenshots

Prepare screenshots that accurately match the submitted build:

- Month calendar view.
- Week calendar view.
- Day calendar view.
- Event creation or editing.
- Holiday subscription settings.
- Language / settings screen.
- Shift entry and work statistics, if included in release messaging.

Avoid screenshots that show placeholder URLs, debug text, simulator artifacts, or unimplemented features as if they were complete.

## 6. Support URL

- Provide a real public support page or contact page.
- Include basic troubleshooting for holiday sync, offline behavior, language settings, and local data.
- Ensure the URL is reachable without authentication.

## 7. Privacy Policy URL

- Publish the final privacy policy based on `Docs/PrivacyPolicyDraft.md`.
- Replace `support@example.com` and placeholder effective dates.
- Ensure the URL is reachable without authentication.
- Ensure the policy explains local data, public ICS URL access, and absence/presence of ads, analytics, tracking, and SDKs.

## 8. Age Rating

- Complete the App Store Connect questionnaire honestly.
- Current app concept is a personal calendar / schedule utility and should generally be suitable for a low age rating.
- Reassess if future versions add user-generated sharing, web browsing, messaging, or external content beyond public ICS sync.

## 9. Review Notes

Draft review notes:

- TimeNest does not require account login.
- The app launches without network access and stores schedules locally by default.
- Holiday subscription sync uses public HTTPS ICS URLs selected inside the app.
- If holiday sync is tested, use a supported region and recommended source from the holiday settings screen.
- Calendar banner ads are included when `AdConfiguration.isEnabled` is `true`; there is currently no in-app remove-ads purchase flow.
- Confirm analytics and tracking statements against the submitted Google Mobile Ads configuration.

## 10. Final Manual Checks Before Submit

- Build and unit tests pass on a macOS/Xcode environment.
- Fresh install and upgrade install pass in TestFlight.
- All supported languages show complete UI strings.
- Placeholder, preview, mock, and debug-only views are either removed or intentionally excluded from user-facing production flows.
- Invalid ICS URL and network failure show user-readable errors.
- App icon, launch screen, display name, version, and build number are final.
