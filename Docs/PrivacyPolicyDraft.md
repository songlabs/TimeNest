# TimeNest Privacy Policy Draft / 隐私政策草案

> Draft only. This document is a product and engineering draft for App Store preparation and is not legal advice or a legal guarantee. Replace placeholders and have the final policy reviewed before publication.

## 中文草案

### TimeNest 隐私政策草案

生效日期：`YYYY-MM-DD`

TimeNest 是一个本地优先的日历与日程管理 App。我们重视用户隐私，并尽量减少数据收集。

### 1. 我们是否收集个人信息

在当前版本中，TimeNest 不包含账号登录或云同步功能，但集成了 Google Mobile Ads，用于在日历页面显示横幅广告。最终发布版本的数据处理说明必须根据实际广告配置、同意流程及 Google 的数据使用说明确认。

### 2. 日历与日程数据

用户在 TimeNest 中创建的日程、备注、班次、工时记录，以及显示语言、周起始日、节假日地区选择、节假日订阅 URL 和节假日缓存数据，默认保存在用户设备本地。当前版本没有账号系统、云同步或 TimeNest 自有后端，也不会将这些数据上传到 TimeNest 自有服务器。

### 3. 节假日订阅

当用户启用或测试节假日订阅时，TimeNest 会访问用户选择的公开 HTTPS ICS URL，以下载节假日数据。该请求会发送到对应的第三方 ICS 服务提供方。第三方服务可能根据其自身政策处理访问日志、IP 地址或请求信息。请在使用前查看对应第三方服务的隐私说明。

### 4. App Group 与 Widget

当前版本包含 Widget Extension。App 与 Widget 使用 App Group 在同一设备上共享 Widget 显示所需的日历快照。该共享用于本机 App 与 Widget 之间的数据交换，不代表云端同步或向 TimeNest 服务器上传。

### 5. 广告、分析与追踪

当前版本集成 Google Mobile Ads。根据 Google 的 iOS App Store 数据披露说明，该 SDK 可能处理 IP 地址（可能用于推断大致位置）、崩溃日志、性能数据、设备标识符、广告数据以及与广告或产品的互动数据。实际处理的数据取决于最终提交版本的 SDK、广告、地区、同意和可选功能配置。

TimeNest 当前没有自行实现独立的分析、账号或后端上传功能，也未实现面向用户的去广告购买流程。发布前必须依据最终广告配置和 Google 的最新说明确认是否访问 IDFA、是否构成追踪、是否需要 ATT 授权或地区性同意流程，并同步更新本政策、Privacy Manifest 和 App Store 隐私标签。

参考：[Google Mobile Ads SDK 的 App Store 数据披露说明](https://developers.google.com/admob/ios/privacy/data-disclosure?hl=zh-CN) 与 [iOS 隐私策略 / ATT 说明](https://developers.google.com/admob/ios/privacy/strategies)。

### 6. 数据删除

用户可以在 App 内删除自己创建的日程，或卸载 App 以删除本地保存的数据。节假日订阅可以在设置中禁用或修改。

### 7. 联系方式

如对隐私政策或数据处理有疑问，请联系开发者：`support@example.com`

## English Draft

### TimeNest Privacy Policy Draft

Effective date: `YYYY-MM-DD`

TimeNest is a local-first calendar and schedule management app. We care about user privacy and aim to minimize data collection.

### 1. Personal Information

The current version does not include account sign-in or cloud sync, but it integrates Google Mobile Ads to display a calendar banner. The final disclosure must be confirmed against the production ad configuration, consent flow, and Google's data-use documentation.

### 2. Calendar and Schedule Data

Schedules, notes, shifts, work-time records, display language, week start settings, holiday region selections, holiday subscription URLs, and cached holiday data created or configured in TimeNest are stored locally on the user's device by default. The current version has no account system, cloud sync, or TimeNest-owned backend, and does not upload this data to TimeNest-owned servers.

### 3. Holiday Subscriptions

When the user enables or tests a holiday subscription, TimeNest accesses the selected public HTTPS ICS URL to download holiday data. This request is sent to the relevant third-party ICS provider. The third-party provider may process access logs, IP addresses, or request information under its own policy. Please review the provider's privacy information before use.

### 4. App Group and Widgets

The current version includes a Widget Extension. The app and widget use an App Group to share the calendar snapshot required for widget display on the same device. This local app-to-widget exchange is not cloud synchronization and does not upload the data to a TimeNest server.

### 5. Advertising, Analytics, and Tracking

The current version integrates Google Mobile Ads. According to Google's iOS App Store data-disclosure guidance, the SDK may process IP addresses (which may estimate general location), crash logs, performance data, device identifiers, advertising data, and advertising or product interaction data. The actual data depends on the SDK, ads, region, consent, and optional features in the submitted build.

TimeNest does not currently implement its own analytics, account system, or backend upload, and it has no user-facing remove-ads purchase flow. Before release, confirm whether the final ad configuration accesses IDFA, constitutes tracking, or requires ATT authorization or regional consent, then update this policy, the Privacy Manifest, and App Store privacy labels consistently.

References: [Google Mobile Ads SDK App Store data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure) and [iOS privacy / ATT strategies](https://developers.google.com/admob/ios/privacy/strategies).

### 6. Data Deletion

Users can delete schedules inside the app or uninstall the app to remove locally stored data. Holiday subscriptions can be disabled or modified in Settings.

### 7. Contact

For questions about this privacy policy or data handling, contact the developer at: `support@example.com`
