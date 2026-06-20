# TimeNest TestFlight Checklist

> Run this checklist against the exact internal TestFlight candidate. Record device model, iOS version, app version/build, language, appearance, and network condition. Current repository behavior includes ads and a Widget Extension, but no user-facing remove-ads purchase flow.

## 1. Internal Test Setup

- [ ] Upload the Release archive and wait for App Store Connect processing to complete.
- [ ] Add the build to the intended internal testing group and complete any required export-compliance information.
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

- [ ] Check Japanese, Simplified Chinese, English, Korean, and System language modes.
- [ ] In each mode, inspect calendar headers, month/week/day labels, settings, event editor, holiday subscription, shift input, statistics, alerts, and Widget text.
- [ ] Confirm no raw keys, mixed unintended languages, truncation, or incorrect date/weekday formatting.
- [ ] Run core flows in light and dark appearance and confirm readable contrast.
- [ ] Inspect a small and a large supported display for clipped calendar rows, controls, sheets, Widget content, or banners.

## 7. Widget and Deep Links

- [ ] Add each Widget family/configuration intended for release and confirm it renders without placeholder-only content.
- [ ] Confirm schedule, shift, holiday, language, and date changes refresh Widget content within expected WidgetKit timing.
- [ ] Tap Widget dates/events and confirm the `timenest` deep link opens TimeNest at the expected date.
- [ ] Relaunch and upgrade the app, then confirm the shared App Group snapshot remains readable by the Widget.

## 8. Ads and Privacy State

- [ ] On the candidate build, confirm the expected banner location, loading/failure behavior, layout, and foreground/background recovery.
- [ ] Confirm production candidates do not use Google's test App ID or banner unit ID. TestFlight-only validation must follow the team's approved AdMob test-device policy.
- [ ] Confirm any ATT prompt, consent form, or privacy-options entry point required by the final configuration appears at the intended time and matches App Store privacy disclosures.
- [ ] If the release intentionally has no ATT prompt, confirm this matches the approved non-ATT ad configuration and disclosures.
- [ ] Confirm no remove-ads purchase or state is shown or promised; the current implementation has no user-facing remove-ads flow.

## 9. Lifecycle, Offline, and Stability

- [ ] Force-quit and relaunch; confirm local schedules, shifts, settings, subscriptions, and Widget data persist.
- [ ] Move the app to background and return to foreground repeatedly during calendar navigation, editing, holiday sync, and ad loading.
- [ ] Launch in airplane mode; confirm existing local data and calendar views remain usable and holiday/ad failures are non-blocking.
- [ ] Switch languages and calendar modes repeatedly, rapidly navigate dates, and delete an event while navigating; confirm no crash, hang, or corrupted state.
- [ ] Review TestFlight crash feedback and Xcode Organizer diagnostics for the candidate build before submission.

## 10. Final Internal-Test Sign-off

- [ ] No release-blocking crash, startup failure, data-loss issue, unreadable screen, broken Widget, or privacy-flow mismatch remains.
- [ ] App Store metadata, screenshots, support URL, privacy-policy URL, version/build, ad configuration, and App Privacy answers match this exact build.
- [ ] Internal tester name, date, result, and known non-blocking issues are recorded for the release decision.
