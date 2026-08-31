# Gemini calendar-cell recognition setup

TimeNest uses Firebase AI Logic with the Gemini Developer API for monthly photo imports. Grid detection and every cell's date remain local. The app sends one cropped day cell to `gemini-3.7-flash`; only a failed cell falls back to Vision OCR. A successful `{"events":[]}` response means that the cell is empty and does not trigger fallback.

## Firebase Apple SDK

The main app target links these Swift Package products from Firebase 12.5.0 or newer within the 12.x release line:

- `FirebaseAILogic`
- `FirebaseAppCheck`
- `FirebaseCore`

The Widget target does not link Firebase App Check.

## Configured Firebase services

The Firebase project uses:

- iOS bundle ID `com.song.TimeNest`
- Firebase AI Logic
- Gemini Developer API
- Firebase App Check
- App Attest as the production provider
- Apple Team ID `JCABFH9F66`

At app launch, TimeNest first checks for a bundled `GoogleService-Info.plist`. If it exists and can be parsed, the app sets the App Check provider and then configures Firebase. If it is absent, Firebase initialization is skipped and the monthly importer reports `firebaseNotConfigured` before using Vision OCR for those cells.

Release builds and physical-device Debug builds use App Attest. Debug Simulator builds use `AppCheckDebugProviderFactory`. Never hard-code, commit, or add a custom log for an App Check debug token.

## GoogleService-Info.plist delivery

`GoogleService-Info.plist` must not be committed. The TestFlight workflow restores it to:

```text
TimeNest/Resources/Firebase/GoogleService-Info.plist
```

from the GitHub Actions secret:

```text
FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64
```

The workflow verifies only that the decoded plist is non-empty and has `BUNDLE_ID=com.song.TimeNest`; it does not print the file or any Firebase identifiers. The Tuist resource glob is optional, so ordinary local builds and iOS CI continue to generate without this file. When the file is present, Tuist adds it only to the main app's Copy Bundle Resources phase.

## CI and release behavior

- Ordinary iOS CI does not receive production Firebase configuration and must build and test with the plist absent. Unit tests use mock cell requesters and never call Gemini.
- TestFlight requires the Firebase plist secret before `tuist generate`.
- The archive verification requires a non-empty `TimeNest.app/GoogleService-Info.plist` with the expected bundle ID.
- The source entitlement, distribution provisioning profile, and signed app entitlement must all contain `com.apple.developer.devicecheck.appattest-environment=production`.

If the archive reports that `TimeNest App Store` does not support the App Attest entitlement, update the App ID capability and distribution provisioning profile in Apple Developer. Do not remove the entitlement, change the Widget profile, or switch release signing to automatic.
