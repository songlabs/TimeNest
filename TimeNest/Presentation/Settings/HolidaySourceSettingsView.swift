import SwiftUI

struct HolidaySourceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject var viewModel: HolidaySubscriptionSettingsViewModel

    @State private var selectedRegion: HolidayRegion?
    @State private var showingEditSheet = false

    // MARK: - DEBUG Logging

    private func makeEditView(for region: HolidayRegion) -> some View {
        return HolidaySourceEditView(
            region: region,
            subscriptionManager: viewModel.subscriptionManager
        )
        .environmentObject(localization)
    }

    @State private var showingResetAlert = false

    var body: some View {
        List {
            ForEach(viewModel.allAvailableSubscriptions) { subscription in
                SourceRowView(
                    subscription: subscription,
                    onTap: {
                        selectedRegion = subscription.region
                        showingEditSheet = true
                    }
                )
            }
        }
        .navigationTitle(localization.localized(.holidaySubscriptionSourceSettings))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(localization.localized(.done)) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let region = selectedRegion {
                makeEditView(for: region)
            }
        }
    }
}

// MARK: - SourceRowView

struct SourceRowView: View {
    let subscription: HolidaySubscription
    let onTap: () -> Void

    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        HStack {
            Text(localization.localized(subscription.displayNameKey))
                .foregroundColor(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // 显示 URL 的前部分
                Text(shortenURL(subscription.urlString))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func shortenURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return localization.localized(.holidaySubscriptionNoURL)
        }

        // 显示 https:// 和最后 20 个字符
        if trimmed.count > 30 {
            let prefix = String(trimmed.prefix(10))
            let suffix = String(trimmed.suffix(15))
            return "\(prefix)...\(suffix)"
        }
        return trimmed
    }
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
    @State private var showingUseSourceAlert = false
    @State private var selectedRecommendedSource: HolidayRecommendedSource?
    @State private var initLogged = false
    @State private var didHideTabBar = false
    @FocusState private var isURLFieldFocused: Bool

    private var subscription: HolidaySubscription? {
        subscriptionManager.subscriptions.first { $0.region == region }
    }

    private var recommendedSources: [HolidayRecommendedSource] {
        HolidayRecommendedSources.sources(for: region)
    }

    private var customHeaderView: some View {
        VStack(spacing: 0) {
            // 返回按钮
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 56, height: 56)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // 标题
            Text(localization.localized(subscription?.displayNameKey ?? region.localizedKey))
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - DEBUG Logging on Init

    private func logInit() {
    }

    // MARK: - DEBUG Logging Helpers

    private func logSaveTapped() {
    }

    private func logSaveSuccess(_ url: String) {
    }

    private func logTestSyncTapped() {
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeaderView

                Form {
                    // MARK: - Error Section (when subscription not found)
                    if subscription == nil {
                        Section {
                            Text(localization.localized(.holidaySubscriptionSourceNotFound))
                                .foregroundColor(.red)
                        }
                    }

                    Section {
                        TextField("https://...", text: $urlString)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .focused($isURLFieldFocused)
                            .onChange(of: urlString) { _, newValue in
                                validateURL(newValue)
                            }
                            .onSubmit {
                                // 按下回车键时失焦，触发自动保存
                                isURLFieldFocused = false
                            }
                    } header: {
                        Text(localization.localized(.holidaySourceURLHeader))
                    } footer: {
                        Text(localization.localized(.holidaySourceURLFooter))
                    }
                    .onChange(of: isURLFieldFocused) { _, newValue in
                        // TextField 失焦时触发自动保存
                        if !newValue {
                            Task {
                                await saveIfNeeded()
                            }
                        }
                    }

                    Section {
                        Button(localization.localized(.holidaySourceTestSync)) {
                            Task {
                                await testSync()
                            }
                        }
                        .disabled(!isValidURL)
                    }

                    // MARK: - Recommended Sources Section
                    if !recommendedSources.isEmpty {
                        Section {
                            if recommendedSources.isEmpty {
                                Text(localization.localized(.holidaySourceNoRecommendedSources))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(recommendedSources) { source in
                                    RecommendedSourceRow(source: source) {
                                        selectedRecommendedSource = source
                                        showingUseSourceAlert = true
                                    }
                                }
                            }
                        } header: {
                            Text(localization.localized(.holidaySourceRecommendedSection))
                        } footer: {
                            Text(localization.localized(.holidaySourceThirdPartyNotice))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
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
            urlString = subscription?.urlString ?? ""
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
        .alert(localization.localized(.holidaySourceUseRecommendedSourceTitle), isPresented: $showingUseSourceAlert) {
            Button(localization.localized(.holidaySourceUseRecommendedSourceConfirm)) {
                applyRecommendedSource()
            }
            Button(localization.localized(.cancel), role: .cancel) {}
        } message: {
            Text(localization.localized(.holidaySourceUseRecommendedSourceMessage))
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
        logSaveTapped()

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

                logSaveSuccess(savedURL)

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

            // 获取对应地区的 clean URL
            let cleanSources = HolidayRecommendedSources.sources(for: region)
            guard let cleanSource = cleanSources.first(where: { $0.isCleanVersion }) else {
                // 没有 clean URL，直接抛出错误
                throw EnhancedICSError.invalidHTTPStatus(statusCode)
            }

            guard let cleanURL = URL(string: cleanSource.urlString) else {
                throw EnhancedICSError.invalidURL
            }


            let data = try await downloadService.download(from: cleanURL, region: regionName, host: host)
            
            // 验证 clean URL 的 ICS 内容（包括 VEVENT 检查）
            // 如果 clean URL 没有事件，抛出错误而不是保存
            try downloadService.validateICSContent(data)
            
            return (data, cleanURL.absoluteString)
        }
    }

    private func applyRecommendedSource() {
        guard let source = selectedRecommendedSource else { return }
        urlString = source.urlString
        validateURL(urlString)
        
        // 立即保存推荐源 URL 到持久层
        Task {
            await saveCurrentURL(urlString)
        }
    }

    private func testSync() async {
        guard let subscription = subscription,
              subscription.isEnabled else {
            errorMessage = localization.localized(.holidaySourceEnableFirst)
            showError = true
            return
        }

        logTestSyncTapped()

        // 使用输入框中的 URL 进行测试，而不是已保存的 URL
        let testURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testURLString.isEmpty else {
            errorMessage = localization.localized(.holidaySubscriptionNoURL)
            showError = true
            return
        }

        do {
            // 下载并解析测试
            guard let url = URL(string: testURLString) else {
                throw EnhancedICSError.invalidURL
            }


            let downloadService = ICSDownloadService()
            let parseService = ICSParseService()

            let host = url.host ?? ""
            let regionName = region.localizedKey
            let data = try await downloadService.download(from: url, region: regionName, host: host)


            // 验证 ICS 内容
            try downloadService.validateICSContent(data)

            let events = try parseService.parse(data: data, region: region, sourceURL: testURLString)


            if events.isEmpty {
                errorMessage = localization.localized(.holidaySourceNoEvents)
                showError = true
            } else {
                syncTestSuccessMessage = String(format: localization.localized(.holidaySourceTestSuccess), events.count)
                showingSyncTestSuccess = true
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - RecommendedSourceRow

struct RecommendedSourceRow: View {
    let source: HolidayRecommendedSource
    let onTap: () -> Void

    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(source.descriptionKey))
                    .foregroundColor(.primary)
                    .font(.body)

                Text(source.host)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HolidaySourceSettingsView(
            viewModel: HolidaySubscriptionSettingsViewModel(
                subscriptionManager: .shared
            )
        )
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
#endif
