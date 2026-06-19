# TimeNest TestFlight Checklist

> This checklist is for pre-release TestFlight verification. Record device model, iOS version, app version, build number, language, and network condition for each run.

## 1. Fresh Install

- Install TimeNest from TestFlight on a device with no previous TimeNest data.
- Launch the app from the Home Screen.
- Confirm the month calendar opens without requiring network access.
- Confirm default language, week start, and holiday subscription state are reasonable.
- Create one all-day event and one timed event.
- Close and reopen the app; confirm events remain visible.

## 2. Permission Denial

- Confirm the current build does not request unused permissions on first launch.
- If a future build adds notifications or system calendar access, deny the permission and verify:
  - The app remains usable.
  - The user sees a clear message or can continue without that permission.
  - No crash or blocked navigation occurs.

## 3. Multilingual UI

Test these modes from Settings:

- Japanese
- Simplified Chinese
- English
- Korean
- System

For each language:

- Verify footer titles, settings rows, buttons, alerts, holiday subscription screens, event editor, statistics, and shift-entry text.
- Verify month titles and weekday headers.
- Verify view mode labels for month / week / day.
- Verify no obvious untranslated placeholder keys appear.

## 4. Month / Week / Day Views

- Month view:
  - Navigate previous and next months.
  - Check month start, month end, and year boundary months.
  - Verify today highlight.
- Week view:
  - Switch from month to week view.
  - Confirm exactly 7 days are displayed.
  - Tap a day and confirm day view opens.
- Day view:
  - Confirm events for the selected date appear in expected order.
  - Confirm empty days do not crash or show broken layout.

## 5. Holiday Subscription

- Enable Japan, China, Korea, and United States regions within the app limit.
- Test recommended source selection.
- Test valid HTTPS ICS sync.
- Test invalid URL input.
- Test an HTTPS URL that returns no events.
- Confirm sync failure shows a user-readable error and does not block the app.
- Confirm disabling all regions hides holidays.

## 6. Offline Testing

- Launch the app in airplane mode.
- Confirm calendar and existing local events load.
- Confirm holiday sync failure is handled gracefully.
- Confirm event create / edit / delete remains available locally.

## 7. Small / Large Screens

Test at least:

- Small iPhone simulator or device.
- Current Pro-size iPhone simulator or device.
- Large iPhone simulator or device.

Check calendar grid, toolbar, settings rows, event editor, statistics, shift entry, alerts, and the ad banner for clipping or inaccessible controls.

## 8. Dark / Light Mode

- Run the full core flow in light mode.
- Run the full core flow in dark mode.
- Confirm text contrast, holiday labels, selected date, today indicator, and bottom toolbar remain readable.

## 9. Upgrade Install

- Install an older TestFlight build if available.
- Create events and set language / week start / holiday regions.
- Upgrade to the candidate build.
- Confirm existing data and settings remain usable.
- Confirm no duplicate or corrupted holiday cache appears after sync.

## 10. Crash / Exception Watch Points

Watch for crashes or hangs when:

- Switching languages repeatedly.
- Rapidly changing month / week / day views.
- Syncing holiday sources with poor network.
- Loading or failing to load the calendar banner ad.
- Deleting events and immediately navigating away.
- Entering empty or malformed event titles and URLs.
