---
name: fix-swiftui-localization-display
description: 修复 SwiftUI 视图中直接显示本地化 key 而非实际文案的问题
source: auto-skill
extracted_at: '2026-05-30T12:07:11.666Z'
---

# 修复 SwiftUI 视图中直接显示本地化 key 的问题

## 场景
当 SwiftUI 视图中的 `Text()` 直接使用字符串字面量作为本地化 key（如 `Text("select_year_month")`）时，如果项目使用自定义的 `LocalizedString` 枚举机制，会导致界面显示 raw key 而非实际本地化文案。

## 问题特征
- 界面显示类似 `select_year_month`、`year_label` 这样的 key 字符串
- 本地化 `.strings` 文件中已有对应的文案
- 项目中已存在 `LocalizedString` 枚举定义（通常在 `Localizable.swift`）

## 修改步骤

### 1. 确认项目本地化机制
检查项目中是否已有 `LocalizedString` 枚举：
```swift
// 通常在 TimeNest/Shared/Localization/Localizable.swift
enum LocalizedString: String {
    case selectYearMonth = "picker.select_year_month"
    case yearLabel = "picker.year_label"
    case monthLabel = "picker.month_label"
    // ...
}
```

### 2. 修改 Text 调用方式
将硬编码的 key 改为使用枚举：

**修改前：**
```swift
Text("select_year_month")
Text("year_label")
Text("month_label")
```

**修改后：**
```swift
Text(LocalizedStringKey(LocalizedString.selectYearMonth.rawValue))
Text(LocalizedStringKey(LocalizedString.yearLabel.rawValue))
Text(LocalizedStringKey(LocalizedString.monthLabel.rawValue))
```

### 3. 验证本地化文件
确认所有目标语言的 `.strings` 文件包含对应的 key：
- `ja.lproj/Localizable.strings`
- `zh-Hans.lproj/Localizable.strings`
- `en.lproj/Localizable.strings`
- `ko.lproj/Localizable.strings`

### 4. 构建验证
```bash
xcodebuild -scheme TimeNest -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## 注意事项

1. **无需额外 import** - 如果 `Localizable.swift` 和修改的文件在同一 target 内，不需要额外 import

2. **无需修改 Localizable.strings** - 如果 key 已存在，只需修改 Swift 代码调用方式

3. **保持一致性** - 项目中应统一使用同一种本地化调用方式，避免混用

4. **Picker 内部标签** - 如果视图包含 Picker，其内部 label 也需要同样修改

## 验证点

1. Build 必须成功
2. 界面不再显示 raw key
3. 切换系统语言后，文案正确变化
4. 所有目标语言都正确显示
