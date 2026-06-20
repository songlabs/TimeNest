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
7. Add the TimeNest Widget and check that schedule, shift, holiday, date, and language changes refresh within normal WidgetKit timing. Tap supported Widget content and confirm TimeNest opens to the expected date.
8. Switch among Japanese, Simplified Chinese, English, Korean, and System language modes. Check key screens for untranslated keys, unexpected mixed language, or clipped text.
9. Test both light and dark appearance, including calendar views, editors, sheets, settings, statistics, Widget content, and any banner area.
10. If banner ads are enabled in this TestFlight build, check the final ad location, layout stability, loading/failure behavior, and return from background. Follow the approved AdMob test-device policy.

Important flows include fresh-install startup, local data persistence after force-quit and relaunch, offline access to existing schedules, all-day event display, holiday refresh failure handling, Widget refresh, and repeated calendar/language/appearance switching.

Known limitations and pending release items:

- There is no account system, developer-operated cloud sync, team sharing, or cross-device data synchronization in this release.
- Public-holiday refresh and ad loading, when ads are enabled, require network access; existing local calendar data should remain usable without network access.
- The current first release has no in-app purchase or remove-ads flow.
- Final production advertising behavior, ATT requirements, App Privacy answers, export-compliance answers, App Store screenshots, and physical-device TestFlight sign-off remain release checks until explicitly completed.
- Apple Developer Program activation must be confirmed before App Store submission.

Feedback contact: https://songlabs.github.io/timenest/support.html

## Internal Submission TODO

- [ ] Confirm the uploaded build's app version/build number and supported Widget configurations.
- [ ] Replace the conditional banner-ad instruction with the exact uploaded-build behavior.
- [ ] Keep the ATT, App Privacy, and export-compliance wording aligned with the final advertising configuration and archive.
- [ ] Complete fresh-install and physical-device TestFlight verification; do not mark it complete based only on this draft.
- [ ] Capture App Store screenshots separately from the exact release candidate after Developer Program access and local launch are available.
