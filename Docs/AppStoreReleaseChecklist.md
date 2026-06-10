# TimeNest App Store 发布前 Checklist

> 本文档用于代码仓库层面的发布准备检查，不代表 Apple 一定审核通过。最终仍需在 Apple Developer、App Store Connect 与 Xcode Organizer 中完成签名、归档、上传和人工元数据确认。

## 1. 代码与配置结论草案

- App 类型：iOS 日历 / 节假日订阅 MVP。
- 最低系统版本：iOS 17.0。
- Bundle ID：`com.song.TimeNest`。
- 签名方式：Automatic Signing，开发团队 ID 已在工程配置中填写；证书、Profile、App Store Connect App 记录需要开发者账号人工确认。
- 当前仓库未发现广告、分析、崩溃收集、IDFA 或跨 App 跟踪 SDK。
- 当前仓库未发现 EventKit、提醒事项、相册、相机、定位、通讯录、麦克风、蓝牙、本地网络等系统权限 API 调用；因此不应在 `Info.plist` 中添加无实际用途的权限说明。
- 已提供 `PrivacyInfo.xcprivacy`，声明不跟踪、不收集数据，并声明 `UserDefaults` 的 Required Reason API 用途。

## 2. App Store Connect 元数据待准备

- App name：建议使用 `TimeNest`，并确认目标市场是否需要本地化名称。
- Subtitle：准备 ja / zh-Hans / en / ko 四种语言的短副标题。
- Description：说明本地日历、节假日订阅、文件导入导出能力；不要承诺云同步或未实现能力。
- Keywords：围绕 calendar、holiday、schedule、日历、祝日、予定、캘린더 等准备，按各语言限制填写。
- Support URL：必须提供可访问的真实支持页面。
- Privacy Policy URL：必须提供可访问的真实隐私政策页面；不要使用占位 URL。
- Marketing URL：可选。
- Category：建议 `Productivity` 或 `Utilities`，最终由产品定位决定。
- Age rating：根据无用户生成内容、无成人内容、无赌博等实际情况填写问卷。
- Screenshots：按 App Store Connect 当前要求准备 iPhone 截图；至少覆盖月 / 周 / 日视图、节假日订阅设置、文件导入导出。
- TestFlight：准备测试说明、反馈邮箱、已知限制说明。

## 3. 隐私标签草案

在当前代码仓库实现范围内：

- Tracking：No。
- Data Used to Track You：None。
- Data Linked to You：None（当前未发现账号、设备 ID、广告 ID、分析或第三方上传）。
- Data Not Linked to You：None（当前未发现分析、崩溃收集或遥测 SDK）。
- 本地数据：用户创建的日历事件、提醒模板/计划、节假日订阅 URL 与缓存文件、语言和周起始日设置保存在本地或 UserDefaults / 本地文件中；当前未发现上传到自有服务器或第三方分析服务的代码。
- 网络访问：仅用于用户配置或内置推荐的 HTTPS ICS 节假日订阅下载。若未来增加云同步、账号、分析、崩溃收集、广告或推送，需要重新填写隐私标签并更新 Privacy Manifest。

## 4. 发布前人工确认项

- 在 Apple Developer Portal 确认 Bundle ID、Signing Certificate、Provisioning Profile、App capability 与工程配置一致。
- 在 Xcode Organizer 完成 Archive、Validate App、Distribute App，不要跳过 App Store Connect 的隐私问卷。
- 确认 App 内“隐私政策 / 使用条款”入口不指向占位 URL；如保留入口，必须替换为真实 URL。
- 使用真机或 TestFlight 验证外部 ICS 下载、无网络状态、无效 URL、文件导入导出、多语言切换和深色模式。
- 确认 App Icon、启动页、版本号、构建号符合发布要求。
