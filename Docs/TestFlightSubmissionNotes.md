# TimeNest TestFlight Submission Notes

> Copy candidate for the TestFlight “What to Test” field. Keep pending items accurate for the uploaded build and do not report screenshots, device checks, or release gates as completed until they have actually been completed.

## Copy-Ready What to Test

TimeNest is a local-first calendar app for schedules, shifts, work records, work statistics, and public-holiday subscriptions. No account or sign-in is required. User-created calendar, shift, and work-record data is stored locally on the device by default.

Please test the following areas:

1. Install TimeNest as a fresh install and confirm it launches without an account or mandatory network connection.
2. Switch among month, week, and day views, navigate dates, and confirm the selected date stays consistent.
3. Create, edit, and delete timed events. Create an all-day event and confirm its all-day presentation in month, week, and day views.
4. Enter, replace, and remove shifts. Confirm shift actions do not remove unrelated schedules or work records.
5. Add work records, including clock-in, clock-out, and break information, then review work statistics for a selected date range.
6. Enable and refresh a supported public-holiday subscription. Confirm downloaded holidays display correctly, and verify that an unavailable or invalid ICS source does not affect existing local schedules.
7. On two devices with separate Apple IDs, create and accept a shared-calendar invitation. Verify that the owner can choose events, shifts, and work records; the recipient remains read-only; calendar-name changes synchronize; and stopping or leaving the share behaves correctly.
8. Add the TimeNest Widget and check that schedule, shift, holiday, date, and language changes refresh within normal WidgetKit timing. Tap supported Widget content and confirm TimeNest opens to the expected date.
9. Switch among Japanese, Simplified Chinese, Traditional Chinese, English, Korean, and System language modes. Check key screens for untranslated keys, unexpected mixed language, or clipped text.
10. Test both light and dark appearance, including calendar views, editors, sheets, settings, statistics, Widget content, and any banner area.
11. Check the banner-ad location, layout stability, loading/failure behavior, and return from background. Follow the approved AdMob test-device policy.
12. On a fresh install, verify UMP completes before the localized ATT prompt. Test both Allow and Ask App Not to Track paths; calendar features must remain available, and denied ad requests must not use IDFA.

Important flows include fresh-install startup, local data persistence after force-quit and relaunch, offline access to existing schedules, all-day event display, holiday refresh failure handling, Widget refresh, and repeated calendar/language/appearance switching. When the App Store `v1.0.0` build is available on a physical device, also verify that upgrading to this candidate preserves an event, shift, work record, and reminder; simulator fixture tests are not equivalent to that upgrade.

Known limitations and pending release items:

- There is no TimeNest account system, developer-operated general cloud sync, or collaborative editing. Optional CloudKit shared calendars synchronize only the owner-selected content, and recipients are read-only.
- Public-holiday refresh and ad loading require network access; existing local calendar data should remain usable without network access.
- The current first release offers a one-time Remove Ads In-App Purchase through Apple StoreKit. Please verify purchase and restore behavior in the uploaded TestFlight/Sandbox environment.
- Final production advertising identifiers, App Privacy/Tracking answers, export-compliance answers, App Store screenshots, and physical-device ATT/TestFlight sign-off remain release checks until explicitly completed.
- Apple Developer Program activation must be confirmed before App Store submission.

Feedback contact: https://songlabs.github.io/timenest/support.html

## Internal Submission TODO

- [ ] Confirm the uploaded build's app version/build number and supported Widget configurations.
- [ ] Confirm the uploaded build uses approved AdMob test-device handling and does not use production traffic for development testing.
- [ ] Keep the ATT implementation, App Privacy/Tracking answers, public privacy policy, Privacy Manifest, and export-compliance wording aligned with the final advertising configuration and archive.
- [ ] Complete fresh-install and physical-device TestFlight verification; do not mark it complete based only on this draft.
- [ ] Complete the physical-device App Store `v1.0.0` upgrade test and record the result separately from local SwiftData migration tests.
- [ ] Capture App Store screenshots separately from the exact release candidate after Developer Program access and local launch are available.
