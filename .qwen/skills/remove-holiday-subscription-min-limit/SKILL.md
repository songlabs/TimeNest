---
name: remove-holiday-subscription-min-limit
description: 移除节假日订阅的"至少启用 1 个"限制，允许用户选择 0 个订阅
source: auto-skill
extracted_at: '2026-05-29T08:03:15.660Z'
---

# 移除节假日订阅最小限制

## 场景
当需要允许用户关闭所有节假日订阅（0 个启用）时，需要移除订阅管理器中的最小订阅限制。

## 修改步骤

### 1. 移除错误码
在 `SubscriptionManagerError` 枚举中移除 `minLimitRequired` 错误码及其对应的 `errorDescription`：

```swift
enum SubscriptionManagerError: Error, LocalizedError {
    case maxLimitExceeded
    // 移除：case minLimitRequired
    case invalidURL
    // ...
}
```

### 2. 移除常量
在 `HolidaySubscriptionManager` 中移除 `minEnabledSubscriptions` 常量：

```swift
private let maxEnabledSubscriptions = 2
// 移除：private let minEnabledSubscriptions = 1
```

### 3. 修改 canDisable 方法
将 `canDisable(subscription:)` 改为始终返回 `true`：

```swift
func canDisable(subscription: HolidaySubscription) -> Bool {
    // 允许禁用所有订阅
    return true
}
```

### 4. 移除 disable 方法中的检查
移除 `disable(subscription:)` 中对 `canDisable` 的检查：

```swift
func disable(subscription: HolidaySubscription) throws {
    // 移除：if !canDisable(subscription: subscription) { throw SubscriptionManagerError.minLimitRequired }
    updateSubscription(subscription.id) {
        $0.isEnabled = false
    }
    // ...
}
```

## 验证点

1. **空订阅兼容性** - 确认以下组件兼容空订阅：
   - `syncAllEnabled()` - 已处理空订阅，返回 `SyncResult(totalEvents: 0, error: nil)`
   - `HolidayUseCase.holidays(regions:from:to:)` - 空 regions 返回空数组
   - `CalendarDisplayUseCase` - 空 holidays 正常显示日历

2. **最大限制保留** - 确保 `maxEnabledSubscriptions = 2` 的限制仍然有效

3. **UI 层验证** - `HolidaySubscriptionSettingsViewModel.canToggle()` 会调用 `canDisable()`，需要确认 UI 正确反映新行为

## 注意事项

- 不需要修改 `HolidayEventCacheRepository` - 它已经兼容空 regions 数组
- 不需要修改 `HolidaySubscriptionSettingsView` - UI 层通过 `canToggle()` 自动适配
- 数据流：空订阅 → 空缓存查询 → 空 holidays → 日历正常显示无节假日
