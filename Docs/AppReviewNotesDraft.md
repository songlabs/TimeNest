# TimeNest App Review Notes Draft

> Copy candidate for the App Review Information notes field. Complete the TODO items against the exact submitted build before pasting it into App Store Connect. Do not include internal TODO text in the final submission.

## Copy-Ready Review Notes

TimeNest does not require account sign-in, and no demo account is needed.

User-created calendar events, shifts, and work records are stored locally on the device by default. The app does not provide developer-operated general cloud sync or upload this content to a TimeNest-operated backend.

For upgrades from version 1.0.0, TimeNest performs a one-time local migration from the former app-sandbox SwiftData store to the current App Group store only when the current store has no user records. The old store is retained and no data is sent over the network by this migration.

To test the main flows, use the calendar controls to switch among month, week, and day views. Create a timed or all-day event, then open it to edit or delete it. In month view, open the calendar's more menu to access Shift Input or Work Statistics. No sign-in or server setup is required.

Public-holiday subscriptions may download ICS data over HTTPS from the public source selected by the reviewer in Settings. Those requests are made to the selected third-party provider. Existing local calendar data remains usable without a successful holiday request.

The Widget, if included in the submitted build, reads a local calendar snapshot shared by the app through the App Group on the same device. This App Group data sharing is not cloud synchronization.

The optional Shared Calendar feature uses the user's Apple iCloud account and CloudKit. Events, shifts, and work records assigned to an owned shared calendar synchronize automatically, and the current implementation has no per-category sharing switches. Received calendars are view-only by default; a recipient can create, edit, or delete events only when the owner enables event editing and the recipient has read-write permission. Shifts and work records remain view-only for recipients. Memos, notifications, voice content, hourly rates, pay, transport fees, app settings, advertising state, and purchase state are not included in shared records.

From an owned or received shared calendar's details, Copy to My Calendar performs a one-time local overwrite for all content or an inclusive selected date range. The result is independent and does not modify or remain synchronized with the shared source.

Google Mobile Ads is integrated, and the first release displays banner ads after the required consent flow permits ad requests. The current first release includes a one-time Remove Ads In-App Purchase handled by Apple StoreKit; restored purchases are based on Apple transaction entitlements.

## Required Pre-Submission TODO

- [ ] **Developer Program:** Confirm enrollment is Active before submission. This does not change the app behavior described above.
- [ ] **Advertising and IAP:** Production AdMob App and Banner Unit IDs are configured; confirm banner behavior for unpurchased and purchased states on the exact submitted build and do not submit a build using placeholders or Google's test identifiers. Confirm the Remove Ads product exists in App Store Connect with product ID `com.song.TimeNest.remove_ads`.
- [ ] **ATT:** Confirm the localized ATT prompt appears after UMP and before advertising on a fresh install, and ensure the review notes, Privacy Manifest, privacy policy, and App Privacy/Tracking answers agree.
- [ ] **Widget:** Confirm the Widget Extension is included and functional in the submitted build; otherwise remove the Widget paragraph.
- [ ] **CloudKit sharing:** Confirm the Production schema and iCloud container are deployed, then verify invitation acceptance, events remaining read-only when editing is disabled, recipient event create/edit/delete when editing is enabled with read-write permission, view-only recipient shifts/work records, and shared-to-personal one-time copy on two physical devices with separate Apple IDs.
- [ ] **Upgrade migration:** Install the App Store `v1.0.0` build on a physical device, create an event, shift, work record, and reminder, then upgrade to the exact candidate and confirm preservation plus Widget refresh. Simulator fixture tests are not equivalent to this check.
- [ ] **Public pages:** Publish and verify the CloudKit updates in the public privacy and support pages; their HTML sources are not in this repository.
- [ ] **Review path:** Recheck the named controls and menus on the exact submitted build so the reviewer instructions remain accurate.

## Facts That Must Remain Consistent

- No account or demo credentials are required.
- No developer-operated general cloud sync is provided; optional shared calendars use Apple iCloud/CloudKit. Recipient event editing is permission-based, while shifts and work records remain view-only for recipients. Copy to My Calendar is a one-time independent local copy, not general cloud sync.
- User-created calendar, shift, and work-record data is local-first.
- Public-holiday subscriptions contact a selected external public ICS provider.
- The release has a one-time Remove Ads In-App Purchase through Apple StoreKit.
- Production Google Mobile Ads identifiers are configured; the final ATT/App Privacy decision and exact-build verification remain manual release gates.
