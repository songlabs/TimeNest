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

    /// 年月、日期、时间值控件的轻量玻璃 tint。
    static let glassCapsuleTint = Color(UIColor { traits in
        UIColor.systemBlue.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.14 : 0.08)
    })

    /// 年月、日期、时间值控件的自适应轻边框。
    static let glassCapsuleBorder = Color(UIColor { traits in
        UIColor.systemBlue.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.24 : 0.14)
    })

    static let floatingPickerBackdropOpacity: Double = 0.10
    static let floatingPickerPanelCornerRadius: CGFloat = 22
    static let floatingPickerPanelBorder = Color(UIColor { traits in
        UIColor.white.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.20 : 0.55)
    })
    static let floatingPickerPanelShadow = Color.black.opacity(0.16)
    
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

    enum Fonts {
        static let popupTitle = Font.headline.weight(.bold)
    }
}

extension View {
    /// Shared material treatment for year, date, and time value capsules.
    func glassCapsuleStyle() -> some View {
        modifier(GlassCapsuleModifier())
    }

    func floatingPickerPanelStyle() -> some View {
        modifier(FloatingPickerPanelModifier())
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Capsule()
                        .fill(.thinMaterial)
                    Capsule()
                        .fill(TimeNestTheme.glassCapsuleTint)
                }
            }
            .overlay {
                Capsule()
                    .stroke(TimeNestTheme.glassCapsuleBorder, lineWidth: 0.6)
            }
            .contentShape(Capsule())
    }
}

private struct FloatingPickerPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: TimeNestTheme.floatingPickerPanelCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: TimeNestTheme.floatingPickerPanelCornerRadius,
                    style: .continuous
                )
                .stroke(TimeNestTheme.floatingPickerPanelBorder, lineWidth: 0.5)
            }
            .shadow(
                color: TimeNestTheme.floatingPickerPanelShadow,
                radius: 14,
                x: 0,
                y: 6
            )
    }
}

struct FloatingPickerOverlay<Content: View>: View {
    private let alignment: Alignment
    private let onDismiss: () -> Void
    private let content: Content

    init(
        alignment: Alignment = .center,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Color.black.opacity(TimeNestTheme.floatingPickerBackdropOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            content
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .zIndex(1)
    }
}

struct FloatingPickerActionRow: View {
    let cancelTitle: String
    let confirmTitle: String
    let confirmColor: Color
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onCancel) {
                Text(cancelTitle)
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(.secondary)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
            }
            .frame(minWidth: 110, maxWidth: 120)

            Button(action: onConfirm) {
                Text(confirmTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(.white)
                    .background(confirmColor)
                    .cornerRadius(10)
            }
            .frame(minWidth: 110, maxWidth: 120)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

enum FloatingDatePickerKind: Equatable {
    case date
    case time
}

struct FloatingDatePickerPanel: View {
    let title: String
    let cancelTitle: String
    let doneTitle: String
    let kind: FloatingDatePickerKind
    let dateRange: ClosedRange<Date>?
    let confirmColor: Color
    let onCancel: () -> Void
    let onDone: (Date) -> Void

    @State private var selection: Date

    init(
        title: String,
        initialSelection: Date,
        cancelTitle: String,
        doneTitle: String,
        kind: FloatingDatePickerKind,
        dateRange: ClosedRange<Date>? = nil,
        confirmColor: Color = .accentColor,
        onCancel: @escaping () -> Void,
        onDone: @escaping (Date) -> Void
    ) {
        self.title = title
        self.cancelTitle = cancelTitle
        self.doneTitle = doneTitle
        self.kind = kind
        self.dateRange = dateRange
        self.confirmColor = confirmColor
        self.onCancel = onCancel
        self.onDone = onDone
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(TimeNestTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            picker

            FloatingPickerActionRow(
                cancelTitle: cancelTitle,
                confirmTitle: doneTitle,
                confirmColor: confirmColor,
                onCancel: onCancel,
                onConfirm: { onDone(selection) }
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: kind == .date ? 340 : 300)
        .floatingPickerPanelStyle()
        .environment(\.locale, LocalizationManager.shared.calendarLocale)
        .environment(\.calendar, LocalizationManager.shared.calendar)
    }

    @ViewBuilder
    private var picker: some View {
        switch kind {
        case .date:
            if let dateRange {
                DatePicker(
                    "",
                    selection: $selection,
                    in: dateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
            } else {
                DatePicker(
                    "",
                    selection: $selection,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
            }
        case .time:
            DatePicker(
                "",
                selection: $selection,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 150)
        }
    }
}

/// Settings-aligned modal shell metrics shared by popup-style surfaces.
enum SettingsModalSurface {
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemGroupedBackground
    })
    static let headerBackground = background
    static let sectionBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : .secondarySystemGroupedBackground
    })
    static let fieldBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : .systemBackground
    })
    static let separator = TimeNestTheme.divider.opacity(0.55)
    static let primaryText = TimeNestTheme.primaryText
    static let secondaryText = TimeNestTheme.secondaryText

    static let topCornerRadius: CGFloat = 28
    static let horizontalPadding: CGFloat = 20
    static let headerVerticalPadding: CGFloat = 14
    static let closeButtonSize: CGFloat = 36
    static let shadowColor = Color.black.opacity(0.12)
}

struct SettingsModalHeaderView: View {
    private let title: Text
    private let closeAction: () -> Void

    init(title: LocalizedStringKey, closeAction: @escaping () -> Void) {
        self.title = Text(title)
        self.closeAction = closeAction
    }

    init(title: String, closeAction: @escaping () -> Void) {
        self.title = Text(title)
        self.closeAction = closeAction
    }

    var body: some View {
        ZStack {
            title
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(SettingsModalSurface.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack {
                Color.clear
                    .frame(
                        width: SettingsModalSurface.closeButtonSize,
                        height: SettingsModalSurface.closeButtonSize
                    )

                Spacer()

                ModalHeaderCloseButton(action: closeAction)
                    .frame(
                        width: SettingsModalSurface.closeButtonSize,
                        height: SettingsModalSurface.closeButtonSize
                    )
            }
        }
        .padding(.horizontal, SettingsModalSurface.horizontalPadding)
        .padding(.vertical, SettingsModalSurface.headerVerticalPadding)
        .background(SettingsModalSurface.headerBackground)
    }
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
    static let size: CGFloat = SettingsModalSurface.closeButtonSize
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
        Color(.tertiarySystemBackground)
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
