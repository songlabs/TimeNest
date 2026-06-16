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

/// Modal / sheet header close button shared by popup-style surfaces.
struct ModalHeaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: ModalHeaderCloseButtonMetrics.iconName)
        }
        .buttonStyle(ModalHeaderCloseButtonStyle())
    }
}

private enum ModalHeaderCloseButtonMetrics {
    static let iconName = "xmark"
    static let size: CGFloat = 36
    static let iconSize: CGFloat = 15
    static let borderWidth: CGFloat = 0.6
    static let pressedScale: CGFloat = 0.94
    static let pressedOpacity: Double = 0.78
    static let disabledOpacity: Double = 0.45

    static var foregroundColor: Color {
        Color(.secondaryLabel)
    }

    static var disabledForegroundColor: Color {
        TimeNestTheme.disabledButtonText
    }

    static var backgroundColor: Color {
        Color(.secondarySystemBackground)
    }

    static var disabledBackgroundColor: Color {
        TimeNestTheme.disabledButtonBackground
    }

    static var borderColor: Color {
        Color(.separator).opacity(0.22)
    }
}

private struct ModalHeaderCloseButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ModalHeaderCloseButtonMetrics.iconSize, weight: .semibold))
            .foregroundColor(isEnabled ? ModalHeaderCloseButtonMetrics.foregroundColor : ModalHeaderCloseButtonMetrics.disabledForegroundColor)
            .frame(
                width: ModalHeaderCloseButtonMetrics.size,
                height: ModalHeaderCloseButtonMetrics.size
            )
            .background(
                Circle()
                    .fill(isEnabled ? ModalHeaderCloseButtonMetrics.backgroundColor : ModalHeaderCloseButtonMetrics.disabledBackgroundColor)
            )
            .overlay(
                Circle()
                    .stroke(ModalHeaderCloseButtonMetrics.borderColor, lineWidth: ModalHeaderCloseButtonMetrics.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? ModalHeaderCloseButtonMetrics.pressedScale : 1)
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(Circle())
    }

    private func opacity(isPressed: Bool) -> Double {
        guard isEnabled else {
            return ModalHeaderCloseButtonMetrics.disabledOpacity
        }
        return isPressed ? ModalHeaderCloseButtonMetrics.pressedOpacity : 1
    }
}
