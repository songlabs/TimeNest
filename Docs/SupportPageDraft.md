# TimeNest Public Support Page Draft

> Manual publication source for https://songlabs.github.io/timenest/support.html. The public-page source is not in this repository, so the URL is **not updated** by this change. Do not add an email address or another support channel unless it is separately verified.

## Supported Languages

- 日本語
- 简体中文
- 繁體中文
- English
- 한국어

## Shared Calendar Support

TimeNest supports optional read-only shared calendars through Apple iCloud (CloudKit). Sharing requires an iCloud account signed in on the device and a working network connection.

The calendar owner can separately choose whether to share:

- events (予定 / 日程)
- shifts (シフト / 班次)
- work records (勤務記録 / 工作记录)

Recipients can view the content selected by the owner, but cannot create, edit, or delete shared content. Private memos, notifications, voice-input content, hourly rates, pay, transport fees, templates, advertising or purchase state, and device/app settings are not shared.

The owner can stop sharing from the Shared Calendar management screen. This revokes recipient access without deleting the owner's local data. A recipient can leave a shared calendar from the same area; TimeNest removes that shared calendar from the recipient's local list and cache without deleting the owner's data.

## Shared Calendar Troubleshooting

If a shared calendar or invitation is unavailable:

1. Confirm that the device is signed in to iCloud.
2. Confirm that the device has a working network connection.
3. Confirm that the recipient accepted the CloudKit share invitation.
4. Retry after a short wait if Apple iCloud or CloudKit is temporarily unavailable.
5. Ask the owner to confirm that sharing is still active and that the intended events, shifts, or work-record switches are enabled.

Shared calendars are not a TimeNest account service and do not use a TimeNest-operated server. Availability and invitation processing depend on Apple iCloud/CloudKit.
