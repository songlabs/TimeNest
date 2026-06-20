import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @AppStorage("weekStart") private var weekStart: String = "system"
    @AppStorage("themeMode") private var themeMode: String = "system"

    @State private var showVersionInfo: Bool = false
    @State private var showingHelp = false
    @StateObject private var subscriptionManager = HolidaySubscriptionManager.shared

    private let onClose: (() -> Void)?

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let onClose {
                VStack(spacing: 0) {
                    SettingsModalHeaderView(
                        title: localization.localized(.settingsTitle),
                        closeAction: onClose
                    )

                    settingsForm
                }
                .background(SettingsModalSurface.background)
            } else {
                settingsForm
                    .navigationTitle(localization.localized(.settingsTitle))
            }
        }
        .onAppear {
            // 执行启动时的自动同步检查
            Task {
                await subscriptionManager.performAutoSync()
            }
        }
        .presentationDetents([.custom(SettingsCompactDetent.self)])
    }

    private var settingsForm: some View {
        ScrollView {
            VStack(spacing: SettingsStyle.sectionSpacing) {
                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsLanguage),
                        selection: Binding(
                            get: { localization.selectedLanguageCode },
                            set: { localization.setLanguage(DisplayLanguage(rawValue: $0) ?? .system) }
                        ),
                        options: [
                            SettingsPickerOption(title: localization.localized(.languageSystem), tag: "system"),
                            SettingsPickerOption(title: localization.localized(.languageSimplifiedChinese), tag: "zhHans"),
                            SettingsPickerOption(title: localization.localized(.languageJapanese), tag: "ja"),
                            SettingsPickerOption(title: localization.localized(.languageKorean), tag: "ko"),
                            SettingsPickerOption(title: localization.localized(.languageEnglish), tag: "enUS")
                        ]
                    )
                }

                SettingsCard {
                    SettingsNavigationRow(
                        title: localization.localized(.settingsHolidayRegion),
                        value: enabledSubscriptionsDisplayText
                    ) {
                        HolidaySubscriptionSettingsView()
                            .environmentObject(localization)
                    }
                }

                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsWeekStart),
                        selection: $weekStart,
                        options: [
                            SettingsPickerOption(title: localization.localized(.weekStartSystem), tag: "system"),
                            SettingsPickerOption(title: localization.localized(.weekStartSunday), tag: "sunday"),
                            SettingsPickerOption(title: localization.localized(.weekStartMonday), tag: "monday"),
                            SettingsPickerOption(title: localization.localized(.weekStartSaturday), tag: "saturday")
                        ]
                    )
                }

                SettingsCard {
                    SettingsNavigationRow(
                        title: localization.localized(.shiftTimeSettingsTitle)
                    ) {
                        ShiftTimeSettingsView()
                            .environmentObject(localization)
                    }
                }

                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsTheme),
                        selection: $themeMode,
                        options: [
                            SettingsPickerOption(title: localization.localized(.themeLight), tag: "light"),
                            SettingsPickerOption(title: localization.localized(.themeDark), tag: "dark"),
                            SettingsPickerOption(title: localization.localized(.themeSystem), tag: "system")
                        ]
                    )
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.settingsSupport))
                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.helpTitle),
                        systemImage: "questionmark.circle"
                    ) {
                        showingHelp = true
                    }
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.settingsAbout))
                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.aboutVersion),
                        value: "1.0.0"
                    )

                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.aboutDeveloper),
                        value: localization.localized(.aboutDeveloperName)
                    )
                }
            }
            .padding(.horizontal, SettingsStyle.horizontalPadding)
            .padding(.top, SettingsStyle.topPadding)
            .padding(.bottom, SettingsStyle.bottomPadding)
        }
        .background(SettingsStyle.background)
        .foregroundColor(SettingsStyle.primaryText)
        .sheet(isPresented: $showingHelp) {
            HelpView()
                .environmentObject(localization)
        }
    }

    private var enabledSubscriptionsDisplayText: String {
        let enabledRegions = subscriptionManager.enabledRegions
        if enabledRegions.isEmpty {
            return localization.localized(.holidaySubscriptionNone)
        }
        return enabledRegions
            .sorted { $0.localizedKey < $1.localizedKey }
            .map { localization.localized($0.localizedKey) }
            .joined(separator: ", ")
    }
}

private enum SettingsStyle {
    static let background = SettingsModalSurface.background
    static let cardBackground = SettingsModalSurface.sectionBackground
    static let primaryText = SettingsModalSurface.primaryText
    static let secondaryText = SettingsModalSurface.secondaryText
    static let divider = SettingsModalSurface.separator

    static let horizontalPadding: CGFloat = TimeNestTheme.externalPadding
    static let sectionSpacing: CGFloat = 16
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 12
    static let sheetCompactHeight: CGFloat = 620
    static let sheetMaximumHeightRatio: CGFloat = 0.82
    static let rowHorizontalPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 56
    static let cardCornerRadius: CGFloat = 26
    static let titleTopPadding: CGFloat = 14
    static let titleBottomPadding: CGFloat = 8
    static let accessorySpacing: CGFloat = 6
    static let rowContentSpacing: CGFloat = 8
    static let rowAccessoryMinSpacing: CGFloat = 8
}

private struct SettingsCompactDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        min(
            SettingsStyle.sheetCompactHeight,
            context.maxDetentValue * SettingsStyle.sheetMaximumHeightRatio
        )
    }
}

private struct SettingsPickerOption: Identifiable {
    let title: String
    let tag: String

    var id: String { tag }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(SettingsStyle.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SettingsStyle.cardCornerRadius, style: .continuous))
    }
}

private struct SettingsCardTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(SettingsStyle.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .padding(.top, SettingsStyle.titleTopPadding)
            .padding(.bottom, SettingsStyle.titleBottomPadding)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsStyle.divider)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, SettingsStyle.rowHorizontalPadding)
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let accessory: Accessory

    init(
        title: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: SettingsStyle.rowContentSpacing) {
            Text(title)
                .font(.body)
                .foregroundColor(SettingsStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Spacer(minLength: SettingsStyle.rowAccessoryMinSpacing)

            accessory
                .layoutPriority(0)
        }
        .frame(minHeight: SettingsStyle.rowMinHeight)
        .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
        .contentShape(Rectangle())
    }
}

private struct SettingsPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [SettingsPickerOption]

    var body: some View {
        SettingsRow(title: title) {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.tag)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(SettingsStyle.secondaryText)
        }
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String?
    let destination: Destination

    init(
        title: String,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SettingsRow(title: title) {
                HStack(spacing: SettingsStyle.accessorySpacing) {
                    if let value {
                        Text(value)
                            .font(.body)
                            .foregroundColor(SettingsStyle.secondaryText)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(SettingsStyle.secondaryText)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsStyle.rowContentSpacing) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(SettingsStyle.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: SettingsStyle.rowAccessoryMinSpacing)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(SettingsStyle.secondaryText)
            }
            .frame(minHeight: SettingsStyle.rowMinHeight)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        SettingsRow(title: title) {
            Text(value)
                .font(.body)
                .foregroundColor(SettingsStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

// MARK: - Shift Time Settings

extension ShiftTimeTemplateID {
    var nameKey: LocalizedString {
        switch self {
        case .day:
            return .shiftDay
        case .night:
            return .shiftNight
        case .custom:
            return .shiftCommon
        }
    }
    
    /// 自定义班次的 UUID 存储 key，用于在 UserDefaults 中记录自定义班次的存在
    var uuidStorageKey: String {
        switch self {
        case .day, .night:
            return ""
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).id"
        }
    }

    var defaultDisplayName: String {
        switch self {
        case .day:
            return LocalizationManager.shared.localized(.shiftDay)
        case .night:
            return LocalizationManager.shared.localized(.shiftNight)
        case .custom:
            return ""
        }
    }

    var defaultStartTime: String {
        switch self {
        case .day:
            return "08:30"
        case .night:
            return "17:00"
        case .custom:
            return "09:00"
        }
    }

    var defaultEndTime: String {
        switch self {
        case .day:
            return "17:30"
        case .night:
            return "09:00"
        case .custom:
            return "18:00"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .day:
            return "#FFD54F"
        case .night:
            return "#5C6BC0"
        case .custom:
            return "#4CAF50"
        }
    }

    var startTimeKey: String {
        switch self {
        case .day:
            return "shiftTime.day.start"
        case .night:
            return "shiftTime.night.start"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).start"
        }
    }

    var endTimeKey: String {
        switch self {
        case .day:
            return "shiftTime.day.end"
        case .night:
            return "shiftTime.night.end"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).end"
        }
    }

    var enabledKey: String {
        switch self {
        case .day:
            return "shiftTime.day.enabled"
        case .night:
            return "shiftTime.night.enabled"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).enabled"
        }
    }

    var displayNameKey: String {
        switch self {
        case .day:
            return "shiftTime.day.displayName"
        case .night:
            return "shiftTime.night.displayName"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).displayName"
        }
    }

    var displayNameCustomizedKey: String {
        "\(displayNameKey).customized"
    }

    var noteKey: String {
        switch self {
        case .day:
            return "shiftTime.day.note"
        case .night:
            return "shiftTime.night.note"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).note"
        }
    }

    var colorHexKey: String {
        switch self {
        case .day:
            return "shiftTime.day.colorHex"
        case .night:
            return "shiftTime.night.colorHex"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).colorHex"
        }
    }

    /// 获取对应的颜色（十六进制版本）
    var colorHex: String {
        defaultColorHex
    }
}

struct ShiftTimeTemplate: Identifiable, Equatable {
    let id: ShiftTimeTemplateID
    let nameKey: LocalizedString
    var displayName: String
    var note: String
    var colorHex: String
    var startTime: String
    var endTime: String
    var enabled: Bool
    var usesLocalizedDefaultName: Bool = false

    var displayTime: String {
        "\(startTime)〜\(endTime)"
    }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    var buttonTextColor: Color {
        // 判断背景色深浅，决定使用深色还是白色文字
        // 将颜色转换为 UIColor 来判断亮度
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // 计算相对亮度 (YIQ 公式)
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        
        // 亮度低于 0.5 使用白色文字，否则使用深色文字（使用黑色确保在白色背景上可见）
        return brightness < 0.5 ? .white : .black
    }

    var startHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: startTime)
    }

    var endHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: endTime)
    }

    static func all(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        // 固定模板：day, night
        let fixedTemplates: [ShiftTimeTemplateID] = [.day, .night]
        var templates: [ShiftTimeTemplate] = []
        
        for id in fixedTemplates {
            // 跳过已删除的模板
            let deletedKey = "shiftTemplate.deleted.\(id.id)"
            if defaults.bool(forKey: deletedKey) {
                continue
            }
            
            let usesLocalizedDefaultName = usesLocalizedDefaultDisplayName(for: id, defaults: defaults)
            let displayName = usesLocalizedDefaultName
                ? id.defaultDisplayName
                : (defaults.string(forKey: id.displayNameKey) ?? id.defaultDisplayName)
            templates.append(ShiftTimeTemplate(
                id: id,
                nameKey: id.nameKey,
                displayName: displayName,
                note: defaults.string(forKey: id.noteKey) ?? "",
                colorHex: defaults.string(forKey: id.colorHexKey) ?? id.defaultColorHex,
                startTime: defaults.string(forKey: id.startTimeKey) ?? id.defaultStartTime,
                endTime: defaults.string(forKey: id.endTimeKey) ?? id.defaultEndTime,
                enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true,
                usesLocalizedDefaultName: usesLocalizedDefaultName
            ))
        }

        // 加载自定义班次
        let customKeys = Set(
            defaults.dictionaryRepresentation()
                .filter { $0.key.hasPrefix("shiftTime.custom.") && $0.key.hasSuffix(".id") }
                .map { String($0.key.prefix($0.key.count - 3)) }
        )

        for prefix in customKeys {
            if let uuidString = defaults.string(forKey: prefix + ".id"),
               let uuid = UUID(uuidString: uuidString) {
                let id = ShiftTimeTemplateID.custom(uuid)
                
                // 跳过已删除的模板
                let deletedKey = "shiftTemplate.deleted.\(id.id)"
                if defaults.bool(forKey: deletedKey) {
                    continue
                }
                
                // 自定义班次优先显示保存的 displayName，为空时才使用默认值
                let displayName = defaults.string(forKey: prefix + ".displayName") ?? ""
                templates.append(ShiftTimeTemplate(
                    id: id,
                    nameKey: id.nameKey,
                    displayName: displayName,
                    note: defaults.string(forKey: id.noteKey) ?? "",
                    colorHex: defaults.string(forKey: id.colorHexKey) ?? id.defaultColorHex,
                    startTime: defaults.string(forKey: id.startTimeKey)
                        ?? defaults.string(forKey: prefix + ".startTime")
                        ?? id.defaultStartTime,
                    endTime: defaults.string(forKey: id.endTimeKey)
                        ?? defaults.string(forKey: prefix + ".endTime")
                        ?? id.defaultEndTime,
                    enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true
                ))
            }
        }

        return templates
    }

    /// 识别旧版本自动保存的内置名称；其他值均视为用户自定义名称。
    static func usesLocalizedDefaultDisplayName(
        for template: ShiftTimeTemplateID,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: template.displayNameCustomizedKey) else {
            return false
        }
        guard let stored = defaults.string(forKey: template.displayNameKey) else {
            return true
        }
        return isKnownDefaultDisplayName(stored, for: template)
    }

    static func isKnownDefaultDisplayName(_ name: String, for template: ShiftTimeTemplateID) -> Bool {
        switch template {
        case .day:
            return ["白", "白班", "日勤", "Day Shift", "주간"].contains(name)
        case .night:
            return ["夜", "夜班", "夜勤", "Night Shift", "야간"].contains(name)
        case .custom:
            return false
        }
    }

    static func isKnownDefaultDisplayName(_ name: String) -> Bool {
        isKnownDefaultDisplayName(name, for: .day)
            || isKnownDefaultDisplayName(name, for: .night)
    }

    static func localizedDisplayName(for storedName: String, templateID: ShiftTimeTemplateID?) -> String {
        guard let templateID, isKnownDefaultDisplayName(storedName, for: templateID) else {
            return storedName
        }
        return templateID.defaultDisplayName
    }

    static func enabled(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        all(from: defaults).filter(\.enabled)
    }

    static func normalizedTimeString(from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func date(from timeString: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        let components = hourMinute(from: timeString) ?? (0, 0)
        return calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: Date()) ?? Date()
    }

    static func hourMinute(from timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    static func == (lhs: ShiftTimeTemplate, rhs: ShiftTimeTemplate) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.note == rhs.note &&
        lhs.colorHex == rhs.colorHex &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.enabled == rhs.enabled &&
        lhs.usesLocalizedDefaultName == rhs.usesLocalizedDefaultName
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        switch length {
        case 6:
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
        case 8:
            let r = Double((rgb & 0xFF000000) >> 24) / 255.0
            let g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            self.init(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    func toHex() -> String {
        // Extract RGBA components using UIColor
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)
        let alpha = Int(a * 255)
        
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
}

// MARK: - ShiftTimeTemplateID Color Extension

extension ShiftTimeTemplateID {
    var color: Color {
        let defaults = UserDefaults.standard
        let colorHex = defaults.string(forKey: self.colorHexKey) ?? self.defaultColorHex
        return Color(hex: colorHex) ?? .gray
    }
}

struct ShiftTimeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @State private var selectedShift: ShiftTimeTemplateID?
    @State private var shiftTemplates: [ShiftTimeTemplate] = []
    @State private var showAddShift: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(localization.localized(.shiftTimeSettingsTitle))
                        .font(TimeNestTheme.Fonts.popupTitle)
                        .foregroundColor(SettingsModalSurface.primaryText)
                    
                    Spacer()
                    
                    ModalHeaderCloseButton {
                        dismiss()
                    }
                }
                .padding(.bottom, 8)
                
                // Shift List
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(shiftTemplates) { template in
                        ShiftTimeSettingsRow(
                            template: template,
                            onDelete: deleteShiftTemplate,
                            onEdit: {
                                selectedShift = template.id
                            }
                        )
                    }
                }
                
                // Add Button
                HStack {
                    Spacer()
                    Button {
                        showAddShift = true
                    } label: {
                        Text(localization.localized(.shiftTimeAddButton))
                            .fontWeight(.medium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .background(SettingsModalSurface.background)
        .sheet(item: $selectedShift) { shiftID in
            ShiftTimeEditSheet(
                shiftID: shiftID,
                onSave: updateShiftTemplate
            )
            .environmentObject(localization)
        }
        .sheet(isPresented: $showAddShift) {
            ShiftTimeEditSheet(
                shiftID: .custom(UUID()),
                isNew: true,
                onSave: addNewShiftTemplate
            )
            .environmentObject(localization)
        }
        .onAppear {
            loadShiftTemplates()
        }
        .onChange(of: localization.selectedLanguageCode) { _, _ in
            loadShiftTemplates()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func loadShiftTemplates() {
        shiftTemplates = ShiftTimeTemplate.all()
    }

    private func deleteShiftTemplate(_ template: ShiftTimeTemplate) {
        // 记录已删除的模板 ID，防止自动恢复
        let deletedKey = "shiftTemplate.deleted.\(template.id.id)"
        UserDefaults.standard.set(true, forKey: deletedKey)
        
        shiftTemplates.removeAll { $0.id == template.id }
        saveShiftTemplates()
    }

    private func updateShiftTemplate(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            shiftTemplates[index] = template
            saveShiftTemplates()
        }
    }

    private func addNewShiftTemplate(_ template: ShiftTimeTemplate) {
        shiftTemplates.append(template)
        saveShiftTemplates()
    }

    private func saveShiftTemplates() {
        let defaults = UserDefaults.standard
        for template in shiftTemplates {
            if template.usesLocalizedDefaultName {
                defaults.removeObject(forKey: template.id.displayNameKey)
                defaults.removeObject(forKey: template.id.displayNameCustomizedKey)
            } else {
                defaults.set(template.displayName, forKey: template.id.displayNameKey)
                if case .day = template.id {
                    defaults.set(true, forKey: template.id.displayNameCustomizedKey)
                } else if case .night = template.id {
                    defaults.set(true, forKey: template.id.displayNameCustomizedKey)
                }
            }
            defaults.set(template.note, forKey: template.id.noteKey)
            defaults.set(template.colorHex, forKey: template.id.colorHexKey)
            defaults.set(template.startTime, forKey: template.id.startTimeKey)
            defaults.set(template.endTime, forKey: template.id.endTimeKey)
            defaults.set(template.enabled, forKey: template.id.enabledKey)
            
            // 保存自定义班次的 UUID，确保可以正确加载
            if case .custom(let uuid) = template.id {
                defaults.set(uuid.uuidString, forKey: template.id.uuidStorageKey)
            }
        }
    }
}


struct ShiftToggleActiveButtonStyle: ButtonStyle {
    static let workAction = ShiftToggleActiveButtonStyle(
        width: 88,
        height: 32,
        cornerRadius: 8,
        font: .subheadline.weight(.semibold)
    )

    var backgroundColor: Color = .blue
    var width: CGFloat = 44
    var height: CGFloat = 28
    var cornerRadius: CGFloat = 6
    var font: Font = .caption.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(.white)
            .frame(width: width, height: height)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ShiftTimeSettingsRow: View {
    let template: ShiftTimeTemplate
    let onDelete: (ShiftTimeTemplate) -> Void
    let onEdit: () -> Void
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Shift Name: 优先显示 displayName，为空时 fallback 到本地化名称
                if !template.displayName.isEmpty {
                    Text(template.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text(localization.localized(template.nameKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                // Time Range
                Text(template.displayTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }

            // Delete Button
            Button(action: { onDelete(template) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

private enum ShiftTimePickerTarget: Hashable {
    case start
    case end
}

private struct ShiftTimeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    let shiftID: ShiftTimeTemplateID
    let isNew: Bool
    let onSave: (ShiftTimeTemplate) -> Void

    @State private var displayName: String
    @State private var note: String
    @State private var color: Color
    @State private var startTime: String
    @State private var endTime: String
    @State private var editingTime: ShiftTimePickerTarget?
    private let initialDisplayName: String
    private let initialUsesLocalizedDefaultName: Bool

    init(shiftID: ShiftTimeTemplateID, isNew: Bool = false, onSave: @escaping (ShiftTimeTemplate) -> Void) {
        self.shiftID = shiftID
        self.isNew = isNew
        self.onSave = onSave
        let defaults = UserDefaults.standard
        let existingTemplate = ShiftTimeTemplate.all(from: defaults).first { $0.id == shiftID }
        let initialDisplayName = isNew
            ? LocalizationManager.shared.localized(.shiftTimeNewShiftName)
            : (existingTemplate?.displayName ?? shiftID.defaultDisplayName)
        self.initialDisplayName = initialDisplayName
        self.initialUsesLocalizedDefaultName = existingTemplate?.usesLocalizedDefaultName ?? false
        _displayName = State(initialValue: initialDisplayName)
        _note = State(initialValue: defaults.string(forKey: shiftID.noteKey) ?? "")
        let defaultHex = defaults.string(forKey: shiftID.colorHexKey) ?? shiftID.defaultColorHex
        _color = State(initialValue: Color(hex: defaultHex) ?? .blue)
        _startTime = State(initialValue: defaults.string(forKey: shiftID.startTimeKey) ?? shiftID.defaultStartTime)
        _endTime = State(initialValue: defaults.string(forKey: shiftID.endTimeKey) ?? shiftID.defaultEndTime)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Form {
                    // 标题（与新規予定一致的 placeholder 样式）
                    Section {
                        TextField(localization.localized(.editorTitle), text: $displayName)
                            .textFieldStyle(.plain)
                    }

                    // 颜色
                    Section {
                        HStack {
                            Text(localization.localized(.shiftTimeColor))
                            Spacer()
                            ColorPicker("", selection: $color)
                        }
                    }

                    // 时间
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(localization.localized(.shiftTimeStartTime))
                                    .font(.subheadline)
                                Spacer()
                                timePickerButton(value: startTime, target: .start)
                            }

                            HStack {
                                Text(localization.localized(.shiftTimeEndTime))
                                    .font(.subheadline)
                                Spacer()
                                timePickerButton(value: endTime, target: .end)
                            }
                        }
                        .padding(.vertical, 8)
                    } footer: {
                        Text(localization.localized(.shiftTimeEditFooter))
                    }
                }
                .navigationTitle(localization.localized(.shiftTimeEditTitle))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localization.localized(.cancel)) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(localization.localized(.save)) {
                            save()
                        }
                    }
                }
            }

            timePickerOverlay
        }
    }

    private func timePickerButton(value: String, target: ShiftTimePickerTarget) -> some View {
        Button {
            editingTime = target
        } label: {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(TimeNestTheme.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassCapsuleStyle()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var timePickerOverlay: some View {
        if let target = editingTime {
            FloatingPickerOverlay(onDismiss: { editingTime = nil }) {
                FloatingDatePickerPanel(
                    title: pickerTitle(for: target),
                    initialSelection: pickerDate(for: target),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .time,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { editingTime = nil },
                    onDone: { selection in
                        applyPickerSelection(selection, to: target)
                        editingTime = nil
                    }
                )
                .id(target)
            }
        }
    }

    private func pickerTitle(for target: ShiftTimePickerTarget) -> String {
        switch target {
        case .start:
            return localization.localized(.shiftTimeStartTime)
        case .end:
            return localization.localized(.shiftTimeEndTime)
        }
    }

    private func pickerDate(for target: ShiftTimePickerTarget) -> Date {
        switch target {
        case .start:
            return ShiftTimeTemplate.date(from: startTime)
        case .end:
            return ShiftTimeTemplate.date(from: endTime)
        }
    }

    private func applyPickerSelection(_ selection: Date, to target: ShiftTimePickerTarget) {
        let normalizedTime = ShiftTimeTemplate.normalizedTimeString(from: selection)
        switch target {
        case .start:
            startTime = normalizedTime
        case .end:
            endTime = normalizedTime
        }
    }

    private func save() {
        // 标题不能为空
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(
                title: localization.localized(.editorError),
                message: localization.localized(.validationTitleRequired),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: localization.localized(.ok), style: .default))
            return
        }
        
        let colorHex = color.toHex()
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesLocalizedDefaultName = initialUsesLocalizedDefaultName
            && normalizedDisplayName == initialDisplayName

        let template = ShiftTimeTemplate(
            id: shiftID,
            nameKey: shiftID.nameKey,
            displayName: normalizedDisplayName,
            note: note,
            colorHex: colorHex,
            startTime: startTime,
            endTime: endTime,
            enabled: true,
            usesLocalizedDefaultName: usesLocalizedDefaultName
        )
        onSave(template)
        dismiss()
    }
}
