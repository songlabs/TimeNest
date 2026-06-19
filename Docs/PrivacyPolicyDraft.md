# TimeNest Privacy Policy Draft / 隐私政策草案

> Draft only. This document is a product and engineering draft for App Store preparation and is not legal advice or a legal guarantee. Replace placeholders and have the final policy reviewed before publication.

## 中文草案

### TimeNest 隐私政策草案

生效日期：`YYYY-MM-DD`

TimeNest 是一个本地优先的日历与日程管理 App。我们重视用户隐私，并尽量减少数据收集。

### 1. 我们是否收集个人信息

在当前版本中，TimeNest 不包含账号登录或云同步功能，但集成了 Google Mobile Ads，用于在日历页面显示横幅广告。最终发布版本的数据处理说明必须根据实际广告配置、同意流程及 Google 的数据使用说明确认。

### 2. 日历与日程数据

用户在 TimeNest 中创建的日程、备注、显示语言、周起始日、节假日地区选择、节假日订阅 URL 和节假日缓存数据默认保存在用户设备本地。当前版本未将这些数据上传到 TimeNest 自有服务器。

### 3. 节假日订阅

当用户启用或测试节假日订阅时，TimeNest 会访问用户选择的公开 HTTPS ICS URL，以下载节假日数据。该请求会发送到对应的第三方 ICS 服务提供方。第三方服务可能根据其自身政策处理访问日志、IP 地址或请求信息。请在使用前查看对应第三方服务的隐私说明。

### 4. 广告、分析与追踪

当前版本集成 Google Mobile Ads。广告请求可能向 Google 发送设备、网络和广告投放相关信息，具体数据类型取决于发布版本的 SDK、广告及同意配置。发布前必须依据 Google 的最新说明确认是否使用 IDFA、是否构成追踪，并同步更新本隐私政策、Privacy Manifest 和 App Store 隐私标签。当前 App 未实现面向用户的去广告购买流程。

### 5. 数据删除

用户可以在 App 内删除自己创建的日程，或卸载 App 以删除本地保存的数据。节假日订阅可以在设置中禁用或修改。

### 6. 联系方式

如对隐私政策或数据处理有疑问，请联系开发者：`support@example.com`

## English Draft

### TimeNest Privacy Policy Draft

Effective date: `YYYY-MM-DD`

TimeNest is a local-first calendar and schedule management app. We care about user privacy and aim to minimize data collection.

### 1. Personal Information

The current version does not include account sign-in or cloud sync, but it integrates Google Mobile Ads to display a calendar banner. The final disclosure must be confirmed against the production ad configuration, consent flow, and Google's data-use documentation.

### 2. Calendar and Schedule Data

Schedules, notes, display language, week start settings, holiday region selections, holiday subscription URLs, and cached holiday data created or configured in TimeNest are stored locally on the user's device by default. The current version does not upload this data to TimeNest-owned servers.

### 3. Holiday Subscriptions

When the user enables or tests a holiday subscription, TimeNest accesses the selected public HTTPS ICS URL to download holiday data. This request is sent to the relevant third-party ICS provider. The third-party provider may process access logs, IP addresses, or request information under its own policy. Please review the provider's privacy information before use.

### 4. Advertising, Analytics, and Tracking

The current version integrates Google Mobile Ads. Ad requests may send device, network, and ad-delivery information to Google; the exact categories depend on the SDK, ad, and consent configuration used in the submitted build. Before release, confirm whether IDFA is used or the configuration constitutes tracking, then update this policy, the Privacy Manifest, and App Store privacy labels consistently. The app currently has no user-facing remove-ads purchase flow.

### 5. Data Deletion

Users can delete schedules inside the app or uninstall the app to remove locally stored data. Holiday subscriptions can be disabled or modified in Settings.

### 6. Contact

For questions about this privacy policy or data handling, contact the developer at: `support@example.com`
