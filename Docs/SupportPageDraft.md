# TimeNest Public Support Page Draft

> Manual publication source for https://songlabs.github.io/timenest/support.html. The public-page source is not in this repository, so the URL is **not updated** by this change. Do not add an email address or another support channel unless it is separately verified.

## Supported Languages

- 日本語
- 简体中文
- 繁體中文
- English
- 한국어

## Shared Calendar Support

TimeNest supports optional shared calendars through Apple iCloud (CloudKit). Sharing requires an iCloud account signed in on the device and a working network connection.

Events, shifts, and work records assigned to an owned shared calendar are synchronized automatically. The current implementation does not provide separate switches for those categories.

Received shared calendars are view-only by default. A recipient can create, edit, or delete events only when the owner allows event editing and the recipient's iCloud permission is read-write. Shifts and work records remain view-only for recipients. Private memos, notifications, voice-input content, hourly rates, pay, transport fees, templates, advertising or purchase state, and device/app settings are not shared.

The owner can stop sharing from the Shared Calendar management screen. This revokes recipient access without deleting the owner's local data. A recipient can leave a shared calendar from the same area; TimeNest removes that shared calendar from the recipient's local list and cache without deleting the owner's data.

### Copy shared calendar to My Calendar

Open an owned or received shared calendar's details and choose **Copy to My Calendar**. Select **All** or **Specify Period**; both the start and end dates are included in a specified period.

Before copying, TimeNest displays an overwrite confirmation. Events, shifts, and work records in the selected range of My Calendar are deleted and replaced with the shared calendar's current contents. Data outside a selected range is preserved. This action cannot be undone.

The copied items are independent local copies. They do not continue syncing with the shared calendar, and copying does not change the shared source. If a received shared calendar has not finished syncing, copying may be temporarily unavailable; refresh it and wait for syncing to finish before trying again.

## Shared Calendar Troubleshooting

If a shared calendar or invitation is unavailable:

1. Confirm that the device is signed in to iCloud.
2. Confirm that the device has a working network connection.
3. Confirm that the recipient accepted the CloudKit share invitation.
4. Retry after a short wait if Apple iCloud or CloudKit is temporarily unavailable.
5. Ask the owner to confirm that sharing is still active and that the intended content is assigned to the owned shared calendar.

Shared calendars are not a TimeNest account service and do not use a TimeNest-operated server. Availability and invitation processing depend on Apple iCloud/CloudKit.
