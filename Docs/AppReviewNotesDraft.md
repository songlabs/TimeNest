# TimeNest App Review Notes Draft

> Copy candidate for the App Review Information notes field. Complete the TODO items against the exact submitted build before pasting it into App Store Connect. Do not include internal TODO text in the final submission.

## Copy-Ready Review Notes

TimeNest does not require account sign-in, and no demo account is needed.

User-created calendar events, shifts, and work records are stored locally on the device by default. The app does not currently provide developer-operated cloud sync or upload this content to a TimeNest-operated backend.

To test the main flows, use the calendar controls to switch among month, week, and day views. Create a timed or all-day event, then open it to edit or delete it. In month view, open the calendar's more menu to access Shift Input or Work Statistics. No sign-in or server setup is required.

Public-holiday subscriptions may download ICS data over HTTPS from the public source selected by the reviewer in Settings. Those requests are made to the selected third-party provider. Existing local calendar data remains usable without a successful holiday request.

The Widget, if included in the submitted build, reads a local calendar snapshot shared by the app through the App Group on the same device. This App Group data sharing is not cloud synchronization.

Google Mobile Ads is integrated, and banner ads may be used depending on the final production configuration. The current first release does not include an in-app purchase or remove-ads flow.

## Required Pre-Submission TODO

- [ ] **Developer Program:** Confirm enrollment is Active before submission. This does not change the app behavior described above.
- [ ] **Advertising:** Replace the conditional advertising paragraph with the exact final behavior of the submitted build. Confirm approved production AdMob identifiers or an intentional ads-disabled configuration; do not submit a build using Google's test identifiers as production identifiers.
- [ ] **ATT:** Confirm whether the final advertising configuration requires ATT and ensure the review notes, permission flow, Privacy Manifest, privacy policy, and App Privacy answers agree.
- [ ] **Widget:** Confirm the Widget Extension is included and functional in the submitted build; otherwise remove the Widget paragraph.
- [ ] **Review path:** Recheck the named controls and menus on the exact submitted build so the reviewer instructions remain accurate.

## Facts That Must Remain Consistent

- No account or demo credentials are required.
- No developer-operated cloud sync is currently provided.
- User-created calendar, shift, and work-record data is local-first.
- Public-holiday subscriptions contact a selected external public ICS provider.
- The release has no in-app purchase or remove-ads flow.
- Final Google Mobile Ads and ATT statements remain manual release decisions.
