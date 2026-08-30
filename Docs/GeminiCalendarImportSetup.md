# Gemini calendar-cell recognition setup

TimeNest uses Firebase AI Logic with the Gemini Developer API for monthly photo imports. Grid detection and cell dates remain local; Gemini receives one cropped day cell per request. If Firebase is not configured, a request fails, or it times out, the existing Vision OCR path runs instead.

## Console setup (not performed by this repository)

1. Create or select a Firebase project in the Firebase console.
2. Add the iOS app with bundle ID `com.song.TimeNest`.
3. In Firebase AI Logic, choose the Gemini Developer API and enable it. Configure App Check and API restrictions before release.
4. Download `GoogleService-Info.plist` and add it to the **TimeNest app target** in the local/generated Xcode project.
5. Do not commit that plist, Gemini API keys, tokens, or other secrets. Distribute it through the team's existing secret/configuration process.
6. Run `tuist install` and `tuist generate` to resolve Firebase and regenerate the workspace.

No Firebase configuration is required for the widget or tests. Without the plist, monthly imports deliberately fall back to Vision OCR.
