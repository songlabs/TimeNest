import SwiftUI

/// TimeNest 统一主题常量
/// 提供项目内统一的背景色、文字色、分隔线等样式，确保深浅模式下一致
enum TimeNestTheme {
    // MARK: - Background Colors
    
    /// 页面背景色 - 跟随系统深浅模式自动切换
    static let pageBackground = Color(.systemGroupedBackground)
    
    /// 卡片背景色 - 跟随系统深浅模式自动切换
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    
    /// 表单/列表背景色 - 跟随系统深浅模式自动切换
    static let listBackground = Color(.systemBackground)
    
    // MARK: - Text Colors
    
    /// 主要文字颜色 - 跟随系统深浅模式自动切换
    static let primaryText = Color.primary
    
    /// 次要文字颜色 - 跟随系统深浅模式自动切换
    static let secondaryText = Color.secondary
    
    /// 占位符文字颜色 - 跟随系统深浅模式自动切换
    static let placeholderText = Color.secondary
    
    // MARK: - Field / Control Colors
    
    /// 输入框/按钮背景色 - 跟随系统深浅模式自动切换
    static let fieldBackground = Color(.systemBackground)
    
    /// 输入框/按钮文字颜色 - 跟随系统深浅模式自动切换
    static let fieldText = Color.primary
    
    /// 输入框/按钮边框色 - 跟随系统深浅模式自动切换
    static let fieldBorder = Color(.systemGray5)
    
    // MARK: - Divider Colors
    
    /// 分隔线颜色 - 跟随系统深浅模式自动切换
    static let divider = Color(.separator)
    
    // MARK: - Button Colors
    
    /// 禁用状态按钮背景色 - 跟随系统深浅模式自动切换
    static let disabledButtonBackground = Color(.systemGray6)
    
    /// 禁用状态按钮文字色 - 跟随系统深浅模式自动切换
    static let disabledButtonText = Color(.systemGray2)
    
    // MARK: - Layout Constants
    
    /// 统一的外部边距（屏幕左右留白）
    static let externalPadding: CGFloat = 16
    
    /// 卡片之间的统一间距
    static let sectionSpacing: CGFloat = 12
    
    /// 统一卡片圆角
    static let cardCornerRadius: CGFloat = 10
    
    /// 统一按钮/输入框圆角
    static let controlCornerRadius: CGFloat = 8
    
    /// 统一小圆角（用于小控件）
    static let smallCornerRadius: CGFloat = 6
}
