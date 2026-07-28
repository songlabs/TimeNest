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
    @State private var isTestingSource = false
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
                                    if !newValue, !isTestingSource {
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
                                    startTestSync()
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
            _ = try await subscriptionManager.validateSourceURL(trimmed, for: region)
            // Preserve the configured normal/custom URL. A clean URL is a
            // per-request fallback and must not replace source identity.
            try subscriptionManager.updateURL(for: region, newURL: trimmed)
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

    private func startTestSync() {
        let testURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        isTestingSource = true
        isURLFieldFocused = false
        Task { @MainActor in
            defer { isTestingSource = false }
            await testSync(testURLString)
        }
    }

    private func testSync(_ testURLString: String) async {
        // 使用点击 Test 时输入框中的 URL，而不是已保存的 URL。
        guard !testURLString.isEmpty else {
            errorMessage = localization.localized(.holidaySubscriptionNoURL)
            showError = true
            return
        }

        do {
            let result = try await subscriptionManager.validateSourceURL(
                testURLString,
                for: region
            )
            syncTestSuccessMessage = String(
                format: localization.localized(.holidaySourceTestSuccess),
                result.eventCount
            )
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
