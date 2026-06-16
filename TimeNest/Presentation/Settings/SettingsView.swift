import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @AppStorage("weekStart") private var weekStart: String = "system"
    @AppStorage("themeMode") private var themeMode: String = "system"
    @AppStorage("notificationEnabled") private var notificationEnabled: Bool = false
    @AppStorage("notificationTimeMinutes") private var notificationTimeMinutes: Int = 9 * 60

    @State private var showVersionInfo: Bool = false
    @State private var notificationTime: Date = SettingsNotificationTime.defaultDate
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
                        .scrollContentBackground(.hidden)
                        .background(SettingsModalSurface.background)
                }
                .background(SettingsModalSurface.background)
            } else {
                settingsForm
                    .navigationTitle(localization.localized(.settingsTitle))
            }
        }
        .onAppear {
            notificationTime = SettingsNotificationTime.date(from: notificationTimeMinutes)
            if notificationEnabled {
                updateDailyNotification(enabled: true)
            }

            // 执行启动时的自动同步检查
            Task {
                await subscriptionManager.performAutoSync()
            }
        }
    }

    private var settingsForm: some View {
        Form {
            // MARK: - Language Section
            Section {
                Picker(localization.localized(.settingsLanguage), selection: Binding(
                    get: { localization.selectedLanguageCode },
                    set: { localization.setLanguage(DisplayLanguage(rawValue: $0) ?? .system) }
                )) {
                    Text(localization.localized(.languageSystem)).tag("system")
                    Text(localization.localized(.languageSimplifiedChinese)).tag("zhHans")
                    Text(localization.localized(.languageJapanese)).tag("ja")
                    Text(localization.localized(.languageKorean)).tag("ko")
                    Text(localization.localized(.languageEnglish)).tag("enUS")
                }
            } header: {
                Text(localization.localized(.settingsLanguage))
            }

            // MARK: - Holiday Subscription Section
            Section {
                NavigationLink {
                    HolidaySubscriptionSettingsView()
                        .environmentObject(localization)
                } label: {
                    HStack {
                        Text(localization.localized(.settingsHolidayRegion))
                        Spacer()
                        Text(enabledSubscriptionsDisplayText)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(localization.localized(.settingsHolidayRegion))
            }

            // MARK: - Week Start Section
            Section {
                Picker(localization.localized(.settingsWeekStart), selection: $weekStart) {
                    Text(localization.localized(.weekStartSystem)).tag("system")
                    Text(localization.localized(.weekStartSunday)).tag("sunday")
                    Text(localization.localized(.weekStartMonday)).tag("monday")
                    Text(localization.localized(.weekStartSaturday)).tag("saturday")
                }
            } header: {
                Text(localization.localized(.settingsWeekStart))
            }

            // MARK: - Shift Time Section
            Section {
                NavigationLink {
                    ShiftTimeSettingsView()
                        .environmentObject(localization)
                } label: {
                    Text(localization.localized(.shiftTimeSettingsTitle))
                }
            } header: {
                Text(localization.localized(.shiftTimeSettingsTitle))
            }

            // MARK: - Notification Section
            Section {
                Toggle(localization.localized(.notificationEnabled), isOn: $notificationEnabled)
                    .onChange(of: notificationEnabled) { enabled in
                        updateDailyNotification(enabled: enabled)
                    }

                DatePicker(
                    localization.localized(.notificationTime),
                    selection: $notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!notificationEnabled)
                .opacity(notificationEnabled ? 1.0 : 0.5)
                .onChange(of: notificationTime) { newValue in
                    notificationTimeMinutes = SettingsNotificationTime.minutes(from: newValue)
                    if notificationEnabled {
                        updateDailyNotification(enabled: true)
                    }
                }
            } header: {
                Text(localization.localized(.settingsNotification))
            }

            // MARK: - Theme Section
            Section {
                Picker(localization.localized(.settingsTheme), selection: $themeMode) {
                    Text(localization.localized(.themeLight)).tag("light")
                    Text(localization.localized(.themeDark)).tag("dark")
                    Text(localization.localized(.themeSystem)).tag("system")
                }
            } header: {
                Text(localization.localized(.settingsTheme))
            }

            // MARK: - About Section
            Section {
                HStack {
                    Text(localization.localized(.aboutVersion))
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(localization.localized(.aboutDeveloper))
                    Spacer()
                    Text(localization.localized(.aboutDeveloperName))
                        .foregroundColor(.secondary)
                }

            } header: {
                Text(localization.localized(.settingsAbout))
            }

        }
        .foregroundColor(.primary)
    }

    private func updateDailyNotification(enabled: Bool) {
        let service = LocalNotificationService()
        let minutes = notificationTimeMinutes

        Task {
            if enabled {
                let authorized = await service.requestAuthorizationIfNeeded()
                await MainActor.run {
                    notificationEnabled = authorized
                }
                if authorized {
                    await service.scheduleDailyScheduleCheck(hour: minutes / 60, minute: minutes % 60)
                } else {
                    service.cancelDailyScheduleCheck()
                }
            } else {
                service.cancelDailyScheduleCheck()
            }
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

enum SettingsNotificationTime {
    static var defaultDate: Date {
        date(from: 9 * 60)
    }

    static func date(from minutes: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        return Calendar.current.date(from: components) ?? Date()
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 9) * 60 + (components.minute ?? 0)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
#endif

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
            return "白班"
        case .night:
            return "夜班"
        case .custom:
            return "新班次"
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
        var templates: [ShiftTimeTemplate] = fixedTemplates.map { id in
            let displayName = migrateDisplayName(
                stored: defaults.string(forKey: id.displayNameKey),
                template: id
            )
            return ShiftTimeTemplate(
                id: id,
                nameKey: id.nameKey,
                displayName: displayName,
                note: defaults.string(forKey: id.noteKey) ?? "",
                colorHex: defaults.string(forKey: id.colorHexKey) ?? id.defaultColorHex,
                startTime: defaults.string(forKey: id.startTimeKey) ?? id.defaultStartTime,
                endTime: defaults.string(forKey: id.endTimeKey) ?? id.defaultEndTime,
                enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true
            )
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
                // 自定义班次优先显示保存的 displayName，为空时才使用默认值
                let displayName = defaults.string(forKey: prefix + ".displayName") ?? ""
                templates.append(ShiftTimeTemplate(
                    id: id,
                    nameKey: id.nameKey,
                    displayName: displayName,
                    note: defaults.string(forKey: prefix + ".note") ?? "",
                    colorHex: defaults.string(forKey: prefix + ".colorHex") ?? id.defaultColorHex,
                    startTime: defaults.string(forKey: prefix + ".startTime") ?? id.defaultStartTime,
                    endTime: defaults.string(forKey: prefix + ".endTime") ?? id.defaultEndTime,
                    enabled: defaults.object(forKey: prefix + ".enabled") as? Bool ?? true
                ))
            }
        }
        
        return templates
    }

    /// 迁移旧默认值：白→白班，夜→夜班
    private static func migrateDisplayName(stored: String?, template: ShiftTimeTemplateID) -> String {
        guard let stored = stored else {
            return template.defaultDisplayName
        }
        // 只对旧默认值做迁移，用户自定义的值保持不变
        switch template {
        case .day:
            if stored == "白" || stored == "日勤" {
                return "白班"
            }
        case .night:
            if stored == "夜" || stored == "夜勤" {
                return "夜班"
            }
        case .custom:
            // 自定义班次不需要迁移
            break
        }
        return stored
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
        lhs.enabled == rhs.enabled
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
    @EnvironmentObject private var localization: LocalizationManager
    @State private var selectedShift: ShiftTimeTemplateID?
    @State private var shiftTemplates: [ShiftTimeTemplate] = []
    @State private var showAddShift: Bool = false

    var body: some View {
        List {
            ForEach(shiftTemplates) { template in
                ShiftTimeSettingsRow(
                    template: template,
                    onToggle: toggleEnabled,
                    onTap: { selectedShift = template.id }
                )
            }
            
            Section {
                Button {
                    showAddShift = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(localization.localized(.shiftTimeAddButton))
                            .foregroundColor(.accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(localization.localized(.shiftTimeSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: shiftTemplates) { _, _ in
            saveShiftTemplates()
        }
    }

    private func loadShiftTemplates() {
        shiftTemplates = ShiftTimeTemplate.all()
    }

    private func toggleEnabled(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            var updated = shiftTemplates[index]
            updated.enabled.toggle()
            shiftTemplates[index] = updated
        }
    }

    private func updateShiftTemplate(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            shiftTemplates[index] = template
        }
    }

    private func addNewShiftTemplate(_ template: ShiftTimeTemplate) {
        shiftTemplates.append(template)
    }

    private func saveShiftTemplates() {
        let defaults = UserDefaults.standard
        for template in shiftTemplates {
            defaults.set(template.displayName, forKey: template.id.displayNameKey)
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
    let onToggle: (ShiftTimeTemplate) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // ON/OFF Button
            Button {
                onToggle(template)
            } label: {
                Text(template.enabled ? "ON" : "OFF")
            }
            .buttonStyle(ShiftToggleActiveButtonStyle(backgroundColor: template.enabled ? .blue : .gray))

            // Shift Name: 优先显示 displayName，为空时 fallback 到本地化名称
            if !template.displayName.isEmpty {
                Text(template.displayName)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
            } else {
                Text(LocalizedStringKey(template.nameKey.rawValue))
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Time Range
            Text(template.displayTime)
                .font(.body)
                .foregroundColor(.secondary)
                .monospacedDigit()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
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

    init(shiftID: ShiftTimeTemplateID, isNew: Bool = false, onSave: @escaping (ShiftTimeTemplate) -> Void) {
        self.shiftID = shiftID
        self.isNew = isNew
        self.onSave = onSave
        let defaults = UserDefaults.standard
        _displayName = State(initialValue: defaults.string(forKey: shiftID.displayNameKey) ?? shiftID.defaultDisplayName)
        _note = State(initialValue: defaults.string(forKey: shiftID.noteKey) ?? "")
        let defaultHex = defaults.string(forKey: shiftID.colorHexKey) ?? shiftID.defaultColorHex
        _color = State(initialValue: Color(hex: defaultHex) ?? .blue)
        _startTime = State(initialValue: defaults.string(forKey: shiftID.startTimeKey) ?? shiftID.defaultStartTime)
        _endTime = State(initialValue: defaults.string(forKey: shiftID.endTimeKey) ?? shiftID.defaultEndTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 显示名称
                Section {
                    HStack {
                        Text(localization.localized(.shiftTimeDisplayName))
                        Spacer()
                        TextField("", text: $displayName)
                            .textFieldStyle(.plain)
                    }
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
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { ShiftTimeTemplate.date(from: startTime) },
                                    set: { startTime = ShiftTimeTemplate.normalizedTimeString(from: $0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }

                        HStack {
                            Text(localization.localized(.shiftTimeEndTime))
                                .font(.subheadline)
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { ShiftTimeTemplate.date(from: endTime) },
                                    set: { endTime = ShiftTimeTemplate.normalizedTimeString(from: $0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text(localization.localized(.shiftTimeEditFooter))
                }
            }
            .navigationTitle(localization.localized(.shiftTimeEditTitle))
            .navigationBarTitleDisplayMode(.inline)
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
    }

    private func save() {
        let colorHex = color.toHex()
        
        let template = ShiftTimeTemplate(
            id: shiftID,
            nameKey: shiftID.nameKey,
            displayName: displayName,
            note: note,
            colorHex: colorHex,
            startTime: startTime,
            endTime: endTime,
            enabled: true
        )
        onSave(template)
        dismiss()
    }
}
