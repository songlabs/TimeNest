# TimeNest TestFlight Checklist

> Run this checklist against the exact internal TestFlight candidate. Record device model, iOS version, app version/build, language, appearance, and network condition. The candidate shows ads to unpurchased users, includes a Widget Extension, and offers a one-time Remove Ads purchase.

## 1. Internal Test Setup

- [ ] Confirm the paid Apple Developer Program membership, agreements, tax, and banking status are active before attempting distribution steps.
- [ ] Upload the Release archive and wait for App Store Connect processing to complete.
- [ ] Add the build to the intended internal testing group and complete the current export-compliance questions using the final archive and `Docs/ExportComplianceNotes.md` as a reference.
- [ ] Paste and recheck `Docs/TestFlightSubmissionNotes.md` against the exact uploaded build, including its Widget, advertising, ATT, and known-limitations wording.
- [ ] Record the tester, device, iOS version, TimeNest version/build, install type, language, and network state.
- [ ] Install from TestFlight on at least one physical device; include one fresh install and, when an older build exists, one upgrade install.
- [ ] Launch from the Home Screen and confirm startup completes without a crash or mandatory network connection.

## 2. Core Calendar Views

- [ ] Month view: navigate previous/next months, cross a year boundary, verify today/selected-date state, and inspect month-edge dates.
- [ ] Week view: switch from month view, confirm seven days and expected events, then navigate previous/next weeks.
- [ ] Day view: open from calendar navigation, confirm timed/all-day ordering, navigate dates, and verify an empty day remains usable.
- [ ] Return among month, week, and day views repeatedly; confirm selection and displayed date remain coherent.

## 3. Schedule Management

- [ ] Create a timed event with title, note, start/end time, and optional reminder; confirm it appears on the expected date.
- [ ] Edit the event and confirm all modified fields persist after closing and reopening the app.
- [ ] Delete the event and confirm it disappears from month, week, day, and Widget data after refresh.
- [ ] Create an all-day event, confirm it appears as all-day in month/week/day views, then edit and delete it.
- [ ] Deny notification permission when prompted for a reminder; confirm the event still saves and the app remains usable.

## 4. Holiday Subscriptions

- [ ] Enable supported regions within the current subscription limit and sync a recommended HTTPS ICS source.
- [ ] Confirm downloaded holidays appear and remain available after relaunch/offline use.
- [ ] Test manual refresh, disable/re-enable, a malformed URL, a request failure, and an ICS response with no usable events.
- [ ] Confirm failures show a readable error and do not remove unrelated local schedules.
- [ ] Confirm holiday names remain native to the holiday region in every app-language mode.

## 5. Shift and Work Records

- [ ] Create or select a shift template and enter shifts across multiple dates.
- [ ] Confirm one-action shift entry, replacement, deletion/cancel behavior, and date advancement match the current product rules.
- [ ] Confirm shift actions do not delete unrelated timed, all-day, clock-in, or clock-out events.
- [ ] Confirm clock-in/out, rest time, transport fee, hourly rate, and work statistics remain consistent where used.

## 6. Languages and Appearance

- [ ] Check Japanese, Simplified Chinese, Traditional Chinese, English, Korean, and System language modes.
- [ ] In each mode, inspect calendar headers, month/week/day labels, settings, event editor, holiday subscription, shift input, statistics, alerts, and Widget text.
- [ ] Confirm no raw keys, mixed unintended languages, truncation, or incorrect date/weekday formatting.
- [ ] Run core flows in light and dark appearance and confirm readable contrast.
- [ ] Inspect a small and a large supported display for clipped calendar rows, controls, sheets, Widget content, or banners.

## 7. Shared Calendars

- [ ] On two devices with separate Apple IDs, verify invitation acceptance and automatic synchronization. With owner event editing disabled, confirm received events are read-only; with editing enabled and a read-write recipient, confirm recipient event create/edit/delete. Recipient shifts and work records must remain view-only.
- [ ] Confirm **Copy to My Calendar** is available from both owned and received shared-calendar details.
- [ ] Verify **All** and **Specify Period**, including that both the selected start and end dates are included.
- [ ] Cancel the destructive overwrite warning and confirm My Calendar is unchanged; then confirm a successful overwrite replaces events, shifts, and work records in scope while preserving data outside a selected range.
- [ ] Copy an empty shared range and confirm only the matching target range is cleared. For a received calendar whose content is not ready, confirm copying is blocked without deleting target data.
- [ ] Confirm a copied custom shift keeps its color and local start/end times. Copy repeated identical shifts and confirm they do not create unnecessary duplicate custom templates.
- [ ] Edit the personal copy and confirm the shared calendar is unchanged. Then change the shared calendar and confirm the personal copy does not update automatically.
- [ ] In Japanese, Simplified Chinese, Traditional Chinese, English, and Korean, inspect the Copy sheet, DatePicker labels and formatting, destructive confirmation, success/error alerts, and Help > Shared Calendars. Confirm no raw keys or clipped text, including on a small display and with larger Dynamic Type.

## 8. Widget and Deep Links

- [ ] Add each Widget family/configuration intended for release and confirm it renders without placeholder-only content.
- [ ] Confirm schedule, shift, holiday, language, and date changes refresh Widget content within expected WidgetKit timing.
- [ ] Tap Widget dates/events and confirm the `timenest` deep link opens TimeNest at the expected date.
- [ ] Relaunch and upgrade the app, then confirm the shared App Group snapshot remains readable by the Widget.

## 9. Ads and Privacy State

- [ ] On the candidate build, confirm the expected banner location, loading/failure behavior, layout, and foreground/background recovery.
- [ ] Confirm the candidate was built with `TIMENEST_ADS_ENABLED=YES` and the approved production App ID and Banner Unit ID.
- [ ] Confirm production candidates do not use Google's test App ID or banner unit ID. TestFlight-only validation must follow the team's approved AdMob test-device policy.
- [ ] Confirm no banner request occurs before UMP reports `canRequestAds == true`; deny or interrupt consent and verify the fixed banner area does not jump.
- [ ] Confirm required UMP consent forms appear at the intended time and Help exposes the privacy-options action only when UMP requires it.
- [ ] On a fresh install, confirm the localized ATT prompt appears only after UMP completes and before the first banner request. Verify both allowed and denied paths; denied must keep the app usable and request ads without IDFA when UMP permits.
- [ ] Verify the Remove Ads purchase and restore flow through TestFlight/Sandbox. Purchased users should not create or reserve space for the banner; unpurchased users should keep the existing banner behavior.

## 10. Lifecycle, Offline, and Stability

- [ ] Force-quit and relaunch; confirm local schedules, shifts, settings, subscriptions, and Widget data persist.
- [ ] Move the app to background and return to foreground repeatedly during calendar navigation, editing, holiday sync, and ad loading.
- [ ] Launch in airplane mode; confirm existing local data and calendar views remain usable and holiday/ad failures are non-blocking.
- [ ] Switch languages and calendar modes repeatedly, rapidly navigate dates, and delete an event while navigating; confirm no crash, hang, or corrupted state.
- [ ] Review TestFlight crash feedback and Xcode Organizer diagnostics for the candidate build before submission.

## 11. Final Internal-Test Sign-off

- [ ] No release-blocking crash, startup failure, data-loss issue, unreadable screen, broken Widget, or privacy-flow mismatch remains.
- [ ] Confirm https://songlabs.github.io/timenest/privacy.html and https://songlabs.github.io/timenest/support.html remain publicly reachable and match this exact build.
- [ ] Review the final App Store screenshots against `Docs/ScreenshotPlan.md`; confirm they contain no test ads, personal data, debug content, or unimplemented feature claims.
- [ ] Complete the App Privacy declaration from `Docs/AppPrivacyAnswersDraft.md` only after the production ad configuration and ATT decision are final.
- [ ] Confirm export-compliance answers, App Store metadata, screenshots, version/build, ad configuration, and App Privacy answers match this exact build.
- [ ] Internal tester name, date, result, and known non-blocking issues are recorded for the release decision.
