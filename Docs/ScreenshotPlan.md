# TimeNest App Store Screenshot Plan

> Planning draft only. Capture screenshots from the exact release candidate without changing UI or adding screenshot assets to the repository. Japanese is the primary-language set; prepare localized variants only for locales selected in App Store Connect.

## Shared Capture Rules

- Use a supported App Store screenshot device size and confirm the current App Store Connect requirements before capture.
- Use fictional, non-personal test data with a coherent month, week, and day story.
- Use release-quality content: no debug labels, simulator chrome, placeholder URLs, permission alerts, test ads, or loading failures.
- Confirm the final banner-ad state before capture. Do not show Google's test ad creative in store screenshots.
- Verify the selected language, date format, week-start setting, appearance, status bar, and Widget state before each capture.
- Do not modify the UI solely to produce these screenshots.

## 1. Month View

- Screenshot goal: Introduce TimeNest's main calendar at a glance.
- Display focus: Full month grid, selected date, a balanced mix of schedules, a shift, and region-native holiday names.
- Suggested language: Japanese for the primary set; matching locale for localized sets.
- Test data needed: Yes - fictional events across several weeks, one or two shifts, and a visible subscribed holiday.
- Pre-capture checks: Correct month and week start; no clipped rows; event titles are readable; no personal data; banner state matches the release plan.

## 2. Week View

- Screenshot goal: Show detailed weekly planning and time placement.
- Display focus: Seven-day context, timed events, all-day content, and clear navigation state.
- Suggested language: Japanese for the primary set.
- Test data needed: Yes - several non-overlapping fictional events plus one representative overlap if it remains readable.
- Pre-capture checks: Correct week and selected date; event times are plausible; overlapping content is not clipped; no temporary alert or sheet is visible.

## 3. Day View

- Screenshot goal: Demonstrate focused daily schedule review.
- Display focus: Timed schedule, all-day item, and readable event detail hierarchy.
- Suggested language: Japanese for the primary set.
- Test data needed: Yes - a realistic but uncluttered day with two or three events.
- Pre-capture checks: Date and weekday are correct; empty gaps look intentional; event titles and times fit; no private notes are exposed.

## 4. Create / Edit Event

- Screenshot goal: Explain how users add or update a schedule.
- Display focus: Event title, date/time controls, all-day option, notes, and reminder fields that exist in the release build.
- Suggested language: Japanese for the primary set.
- Test data needed: Yes - a fictional event with safe sample text and realistic times.
- Pre-capture checks: No keyboard obscures required controls; fields contain no personal information; values are valid; do not imply cloud sharing or collaboration.

## 5. Shift Input

- Screenshot goal: Present fast shift entry and its relationship to the calendar.
- Display focus: `シフト入力`, selected date, available shift template, and the current entry controls.
- Suggested language: Japanese for the primary set; use the localized shift-input wording in other sets.
- Test data needed: Yes - clearly named fictional shift templates and several already-entered shifts.
- Pre-capture checks: Template names fit; selected date is obvious; ordinary schedules remain distinct from shifts; no claim implies payroll, employer integration, or cloud sync.

## 6. Settings / Holiday Subscription

- Screenshot goal: Show personalization and public-holiday subscription support.
- Display focus: Language/appearance settings and the holiday subscription entry or sheet with a supported region and public HTTPS source.
- Suggested language: Japanese for the primary set.
- Test data needed: Yes - enable a supported fictional demonstration state using a recommended public source; avoid showing a user-entered private URL.
- Pre-capture checks: Subscription state is valid; no error or loading state; provider/holiday language is accurate; no sensitive URL query data; settings text is not clipped.

## Optional Follow-up Screenshots

- Work statistics, if the release messaging needs a seventh screenshot and the displayed figures use fictional data.
- Widget, only if it accurately represents the submitted Widget and adds information not already covered by the six core screenshots.

## Final Capture TODO

- [ ] Confirm App Store Connect screenshot dimensions and locale coverage.
- [ ] Prepare the Japanese primary set from the final release candidate.
- [ ] Prepare approved `zh-Hans`, `en`, and `ko` variants where those product pages will be localized.
- [ ] Review every image for personal data, test ads, debug content, clipping, and unimplemented feature claims.
