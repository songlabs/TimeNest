# GitHub Actions to TestFlight

## Repository configuration

The project uses `TimeNest.xcodeproj`, the shared `TimeNest` scheme, and Apple team `JCABFH9F66`. Main App and Widget Debug builds use automatic signing. TestFlight Release archives use manual signing with one fixed Apple Distribution certificate and the fixed `TimeNest App Store` / `TimeNest Widget App Store` profiles. The Release archive contains the `TimeNest` app (`com.song.TimeNest`) and `TimeNestWidgetExtension` (`com.song.TimeNest.TimeNestWidgetExtension`). CI does not regenerate the project with Tuist: `Project.swift` is the source manifest, while the checked-in Xcode project is the build input.

The workflows run on GitHub-hosted `macos-15` and explicitly select `/Applications/Xcode_26.3.app`; they do not rely on the runner's default Xcode. Each job prints `xcodebuild -version` and the iPhoneOS SDK version, then fails before dependency resolution unless the SDK major version is at least 26. Ordinary pushes to `main` and pull requests run simulator unit tests and a Release simulator build. They never upload. Only a manual run of the **TestFlight** workflow archives and uploads.

The manual workflow overrides `CURRENT_PROJECT_VERSION` for every target with the UTC Unix timestamp. It does not edit or commit `MARKETING_VERSION` or the project file.

## Required GitHub environment and secrets

In GitHub, open **Settings → Environments**, create an environment named `testflight`, then add these environment secrets:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | The App Store Connect API key ID. |
| `ASC_ISSUER_ID` | The issuer ID shown on the App Store Connect Integrations page. |
| `ASC_PRIVATE_KEY` | The complete contents of the downloaded `AuthKey_<KEY_ID>.p8` file, including its BEGIN/END lines. |
| `APPLE_DISTRIBUTION_P12_BASE64` | Base64 for the existing Apple Distribution certificate and its private key exported as a password-protected `.p12`. |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | Password used when exporting that `.p12`. |
| `PROFILE_TIMENEST_BASE64` | Base64 for the active App Store profile named `TimeNest App Store` and bundle ID `com.song.TimeNest`. |
| `PROFILE_TIMENEST_WIDGET_BASE64` | Base64 for the active App Store profile named `TimeNest Widget App Store` and bundle ID `com.song.TimeNest.TimeNestWidgetExtension`. |

Create the key in **App Store Connect → Users and Access → Integrations → App Store Connect API** with an **App Manager** role. Download the `.p8` once and store it directly as the secret; never add it to this repository. The API key remains limited to upload and App Store Connect operations; Archive and Export do not use it to create or fetch signing resources.

The API key must have access to the TimeNest app. Before encoding the profiles, confirm that both are active, unexpired App Store profiles linked to the same fixed Apple Distribution certificate. The Main profile must include App Group, iCloud/CloudKit Production, iCloud Extended Share Access, and WeatherKit; the Widget profile must include its App Group. The workflow validates these properties before Archive and does not use `-allowProvisioningUpdates` or any automatic-signing fallback. No certificate, profile, or password is committed or uploaded as an artifact.

On the first signed run, preserve the complete non-sensitive output from the signing-material validation, `xcodebuild archive`, or `xcodebuild -exportArchive` step if certificate/profile matching fails. Do not change either bundle ID or remove App Group, CloudKit, WeatherKit, Widget, or other entitlements to bypass it. Regenerate only the affected App Store profile against the existing distribution certificate, replace its GitHub Environment secret, and retry. The retained archive/export logs make this diagnosis possible without exposing the private key.

## Manual release

1. Push the desired commit to GitHub.
2. Open **Actions → TestFlight → Run workflow** and select the desired branch.
3. Wait for Build/Test, archive, entitlement verification, IPA export, upload, Apple processing, and internal-group assignment.
4. Open TestFlight on the iPhone and install the new build from `songlabs Internal Test`.

The workflow uses the App Store Connect API after processing to assign the exact uploaded build to `songlabs Internal Test`; App Store Connect's automatic distribution option is not required. The upload is for internal testing only and does not submit an App Store version for review.

## What CI verifies

- Stable unit tests: all `TimeNestTests` in the shared scheme, using the newest available iOS 26-or-newer iPhone simulator runtime. UI and screenshot tests are intentionally excluded because they are longer-running end-to-end suites and may require controlled simulator state.
- Release compilation on simulator in the ordinary CI workflow.
- A signed Release device archive in the manual workflow.
- Presence and validity of both embedded provisioning profiles and the nested code signature.
- Production CloudKit, CloudKit container, WeatherKit, and App Group entitlements on the app, and the App Group entitlement on the Widget.
- IPA export, App Store Connect upload, processing state, and assignment to the named internal group.

Physical-device behavior, production CloudKit data, WeatherKit responses, Widget refresh timing, purchases/ads, and installation from TestFlight remain iPhone checks after each candidate is uploaded.

## Failure diagnostics

Both workflows retain test results and non-secret build logs for seven days. The TestFlight workflow does not retain the archive or IPA because they contain signed production binaries and embedded provisioning profiles. The temporary API key, imported profiles, `.p12`, signing directory, and temporary keychain are removed in `always()` steps.
