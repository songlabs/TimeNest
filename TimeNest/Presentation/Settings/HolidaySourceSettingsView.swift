import SwiftUI

private enum HolidaySourceStyle {
    static let textAreaBackground = Color(UIColor { traits in
        UIColor.systemBlue.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.18 : 0.10)
    })
}

// MARK: - HolidaySourceEditView

struct HolidaySourceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject private var tabBarVisibility = TabBarVisibilityState.shared

    let region: HolidayRegion
    let subscriptionManager: HolidaySubscriptionManager

    @State private var urlString: String = ""
    @State private var isValidURL = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingSyncTestSuccess = false
    @State private var syncTestSuccessMessage = ""
    @State private var didHideTabBar = false
    @FocusState private var isURLFieldFocused: Bool

    private var subscription: HolidaySubscription? {
        subscriptionManager.subscriptions.first { $0.region == region }
    }

    private var defaultURLString: String {
        HolidayRecommendedSources.preferredURL(for: region) ?? ""
    }

    private var defaultURLHost: String {
        URL(string: defaultURLString)?.host ?? "www.officeholidays.com"
    }

    private var customHeaderView: some View {
        SettingsModalHeaderView(
            title: localization.localized(.holidaySourceURLHeader),
            closeAction: { dismiss() }
        )
    }

    var body: some View {
        ZStack {
            SettingsModalSurface.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeaderView

                ScrollView {
                    VStack(alignment: .leading, spacing: WorkStatisticsLayout.sectionSpacing) {
                        // MARK: - Error Section (when subscription not found)
                        if subscription == nil {
                            Text(localization.localized(.holidaySubscriptionSourceNotFound))
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(localization.localized(.holidaySourceURLFooter))
                                .font(.footnote)
                                .foregroundColor(SettingsModalSurface.secondaryText)

                            TextEditor(text: $urlString)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .focused($isURLFieldFocused)
                                .font(.body)
                                .foregroundColor(SettingsModalSurface.primaryText)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(height: 96, alignment: .topLeading)
                                .background(HolidaySourceStyle.textAreaBackground)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: WorkStatisticsLayout.cardCornerRadius,
                                        style: .continuous
                                    )
                                )
                                .onChange(of: urlString) { _, newValue in
                                    validateURL(newValue)
                                }
                                .onChange(of: isURLFieldFocused) { _, newValue in
                                    if !newValue {
                                        Task {
                                            await saveIfNeeded()
                                        }
                                    }
                                }

                            HStack(spacing: 12) {
                                Button(localization.localized(.holidaySourceDefault)) {
                                    restoreDefaultURL()
                                }
                                .buttonStyle(
                                    HolidaySourceBlueButtonStyle(
                                        isFullWidth: true,
                                        height: 44,
                                        cornerRadius: 10,
                                        font: .headline.weight(.semibold)
                                    )
                                )

                                Button(localization.localized(.holidaySourceTestSync)) {
                                    Task {
                                        await testSync()
                                    }
                                }
                                .buttonStyle(
                                    HolidaySourceBlueButtonStyle(
                                        isFullWidth: true,
                                        height: 44,
                                        cornerRadius: 10,
                                        font: .headline.weight(.semibold)
                                    )
                                )
                                .disabled(!isValidURL)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(localization.localized(.holidaySourceDefaultURLProvider))
                                    .font(.body)
                                    .foregroundColor(SettingsModalSurface.primaryText)

                                Text(defaultURLHost)
                                    .font(.subheadline)
                                    .foregroundColor(SettingsModalSurface.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(SettingsModalSurface.fieldBackground)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: WorkStatisticsLayout.cardCornerRadius,
                                style: .continuous
                            )
                        )
                    }
                    .padding(.horizontal, WorkStatisticsLayout.horizontalPadding)
                    .padding(.top, WorkStatisticsLayout.sectionSpacing)
                    .padding(.bottom, WorkStatisticsLayout.horizontalPadding)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("")
        .onAppear {
            if !didHideTabBar {
                tabBarVisibility.hide()
                didHideTabBar = true
            }
            if let savedURL = subscription?.urlString,
               !savedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                urlString = savedURL
            } else {
                urlString = defaultURLString
            }
            validateURL(urlString)
        }
        .onDisappear {
            if didHideTabBar {
                tabBarVisibility.show()
                didHideTabBar = false
            }
        }
        .alert(localization.localized(.holidaySourceError), isPresented: $showError) {
            Button(localization.localized(.ok), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(localization.localized(.holidaySourceTestSuccessTitle), isPresented: $showingSyncTestSuccess) {
            Button(localization.localized(.ok), role: .cancel) {}
        } message: {
            Text(syncTestSuccessMessage)
        }
    }

    private func restoreDefaultURL() {
        let wasFocused = isURLFieldFocused
        urlString = defaultURLString
        validateURL(urlString)

        if wasFocused {
            isURLFieldFocused = false
        } else {
            Task {
                await saveCurrentURL(urlString)
            }
        }
    }

    private func validateURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              let urlObj = URL(string: trimmed),
              let scheme = urlObj.scheme,
              scheme.lowercased() == "https" else {
            isValidURL = false
            return
        }

        isValidURL = true
    }

    /// 统一保存函数：保存当前 URL 到持久层
    /// - Parameter url: 要保存的 URL 字符串
    private func saveCurrentURL(_ url: String) async {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalURL = subscription?.urlString ?? ""

        // 如果与原值相同，不保存
        if trimmed == originalURL {
            return
        }

        // 空字符串允许保存（用于清除 URL）
        if trimmed.isEmpty {
            do {
                try subscriptionManager.updateURL(for: region, newURL: "")
                _ = await subscriptionManager.syncAllEnabled()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            return
        }

        // 检查是否为有效 URL
        guard let urlObj = URL(string: trimmed),
              let scheme = urlObj.scheme,
              scheme.lowercased() == "https" else {
            // 无效 URL 或不使用 HTTPS，不保存
            return
        }

        // 尝试保存
        do {
            let downloadService = ICSDownloadService()
            try downloadService.validateURL(trimmed)

            guard let url = URL(string: trimmed) else {
                throw EnhancedICSError.invalidURL
            }
            let host = url.host ?? ""
            let regionName = region.localizedKey
            let (data, savedURL) = try await downloadWithFallback(
                url: url,
                regionName: regionName,
                host: host,
                downloadService: downloadService
            )

            try downloadService.validateICSContent(data)

            let parseService = ICSParseService()
            let events = try parseService.parse(data: data, region: region, sourceURL: savedURL)

            guard !events.isEmpty else {
                throw EnhancedICSError.noEvents
            }

            try subscriptionManager.updateURL(for: region, newURL: savedURL)
            _ = await subscriptionManager.syncAllEnabled()

        } catch {
            // 保存失败，显示错误提示
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    /// 自动保存：仅在输入与原值不同时保存
    /// 失焦时调用，支持空字符串保存
    private func saveIfNeeded() async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalURL = subscription?.urlString ?? ""

        // 如果与原值相同，不保存
        if trimmed == originalURL {
            return
        }

        // 空字符串允许保存
        if trimmed.isEmpty {
            await saveCurrentURL("")
            return
        }

        // 检查是否为 HTTPS URL
        guard let urlObj = URL(string: trimmed),
              let scheme = urlObj.scheme,
              scheme.lowercased() == "https" else {
            // 无效 URL 或不使用 HTTPS，不保存
            return
        }

        await saveCurrentURL(trimmed)
    }

    private func saveURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                // 1. URL 格式检查
                let downloadService = ICSDownloadService()
                try downloadService.validateURL(trimmed)

                // 2. 下载 ICS（带 fallback 逻辑）
                guard let url = URL(string: trimmed) else {
                    throw EnhancedICSError.invalidURL
                }
                let host = url.host ?? ""
                let regionName = region.localizedKey
                let (data, savedURL) = try await downloadWithFallback(
                    url: url,
                    regionName: regionName,
                    host: host,
                    downloadService: downloadService
                )


                // 3. 验证 ICS 内容（包括 VEVENT 检查）
                try downloadService.validateICSContent(data)

                // 4. 解析 ICS 以确认可以提取出节假日事件
                let parseService = ICSParseService()
                let events = try parseService.parse(data: data, region: region, sourceURL: savedURL)


                // 5. 确保至少解析出一个事件才允许保存
                guard !events.isEmpty else {
                    throw EnhancedICSError.noEvents
                }

                // 6. 保存 URL（保存实际成功的 URL）
                try subscriptionManager.updateURL(for: region, newURL: savedURL)


                // 7. 成功后自动同步
                _ = await subscriptionManager.syncAllEnabled()

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    /// 下载 ICS 并自动尝试 fallback URL
    /// - 如果 normal URL 返回 500，自动尝试 clean URL
    /// - 返回实际成功的 URL
    /// - clean URL 也必须通过 VEVENT 检查，否则抛出错误
    private func downloadWithFallback(
        url: URL,
        regionName: String,
        host: String,
        downloadService: ICSDownloadService
    ) async throws -> (Data, String) {

        do {
            let data = try await downloadService.download(from: url, region: regionName, host: host)
            
            // 验证 ICS 内容（包括 VEVENT 检查）
            try downloadService.validateICSContent(data)
            
            return (data, url.absoluteString)
        } catch EnhancedICSError.invalidHTTPStatus(let statusCode) where statusCode == 500 {
            // HTTP 500 时尝试 fallback 到 clean URL

            guard isOfficeHolidaysURL(url),
                  let cleanURLString = HolidayRecommendedSources.cleanFallbackURL(for: region),
                  let cleanURL = URL(string: cleanURLString) else {
                // 没有 clean URL，直接抛出错误
                throw EnhancedICSError.invalidHTTPStatus(statusCode)
            }

            let data = try await downloadService.download(from: cleanURL, region: regionName, host: host)
            
            // 验证 clean URL 的 ICS 内容（包括 VEVENT 检查）
            // 如果 clean URL 没有事件，抛出错误而不是保存
            try downloadService.validateICSContent(data)
            
            return (data, cleanURL.absoluteString)
        }
    }

    private func isOfficeHolidaysURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "www.officeholidays.com" || host == "officeholidays.com"
    }

    private func testSync() async {
        // 使用输入框中的 URL 进行测试，而不是已保存的 URL
        let testURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testURLString.isEmpty else {
            errorMessage = localization.localized(.holidaySubscriptionNoURL)
            showError = true
            return
        }

        do {
            let downloadService = ICSDownloadService()
            try downloadService.validateURL(testURLString)

            // 下载并解析测试
            guard let url = URL(string: testURLString) else {
                throw EnhancedICSError.invalidURL
            }

            let parseService = ICSParseService()

            let host = url.host ?? ""
            let regionName = region.localizedKey
            let data = try await downloadService.download(from: url, region: regionName, host: host)


            // 验证 ICS 内容
            try downloadService.validateICSContent(data)

            let events = try parseService.parse(data: data, region: region, sourceURL: testURLString)

            guard !events.isEmpty else {
                throw EnhancedICSError.noEvents
            }

            syncTestSuccessMessage = String(format: localization.localized(.holidaySourceTestSuccess), events.count)
            showingSyncTestSuccess = true

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}


// MARK: - HolidaySource Button Styles

private struct HolidaySourceBlueButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isFullWidth = false
    var height: CGFloat = 36
    var cornerRadius: CGFloat = 10
    var font: Font = .subheadline.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: height)
            .background(isEnabled ? ShiftCalendarColors.primaryBlue : TimeNestTheme.disabledButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
