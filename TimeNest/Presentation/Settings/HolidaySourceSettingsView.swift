import SwiftUI

struct HolidaySourceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject var viewModel: HolidaySubscriptionSettingsViewModel

    @State private var selectedRegion: HolidayRegion?
    @State private var showingEditSheet = false
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
                HolidaySourceEditView(
                    region: region,
                    subscriptionManager: viewModel.subscriptionManager
                )
                .environmentObject(localization)
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

    let region: HolidayRegion
    let subscriptionManager: HolidaySubscriptionManager

    @State private var urlString: String = ""
    @State private var isValidURL = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingResetAlert = false
    @State private var showingUseSourceAlert = false
    @State private var selectedRecommendedSource: HolidayRecommendedSource?

    private var subscription: HolidaySubscription? {
        subscriptionManager.subscriptions.first { $0.region == region }
    }

    private var recommendedSources: [HolidayRecommendedSource] {
        HolidayRecommendedSources.sources(for: region)
    }

    // MARK: - DEBUG Logging Helpers

    private func logSaveTapped() {
        #if DEBUG
        print("[HolidaySourceSettings] save tapped")
        print("[HolidaySourceSettings] region =", region.rawValue)
        print("[HolidaySourceSettings] input urlString =", urlString)
        print("[HolidaySourceSettings] current saved URL before =", subscription?.urlString ?? "nil")
        #endif
    }

    private func logSaveSuccess(_ url: String) {
        #if DEBUG
        print("[HolidaySourceSettings] saved URL after =", url)
        #endif
    }

    private func logTestSyncTapped() {
        #if DEBUG
        print("[HolidaySourceSettings] sync test tapped")
        print("[HolidaySourceSettings] sync test URL =", urlString)
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://...", text: $urlString)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .onChange(of: urlString) { _, newValue in
                            validateURL(newValue)
                        }
                } header: {
                    Text(localization.localized(.holidaySourceURLHeader))
                } footer: {
                    Text(localization.localized(.holidaySourceURLFooter))
                }

                Section {
                    if let urlString = subscription?.urlString, !urlString.isEmpty {
                        HStack {
                            Text(localization.localized(.holidaySourceCurrentURL))
                            Spacer()
                            Text(urlString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section {
                    Button(localization.localized(.holidaySourceResetDefault)) {
                        showingResetAlert = true
                    }
                    .foregroundColor(.orange)
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
                Section {
                    Text(localization.localized(.holidaySourceRecommendedSection))
                        .font(.headline)
                        .foregroundColor(.primary)
                }

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
                } footer: {
                    Text(localization.localized(.holidaySourceThirdPartyNotice))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(localization.localized(subscription?.displayNameKey ?? region.localizedKey))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.save)) {
                        saveURL()
                    }
                    .disabled(!isValidURL || urlString == (subscription?.urlString ?? ""))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                urlString = subscription?.urlString ?? ""
                validateURL(urlString)
            }
            .alert(localization.localized(.holidaySourceError), isPresented: $showError) {
                Button(localization.localized(.ok), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(localization.localized(.holidaySourceResetConfirm), isPresented: $showingResetAlert) {
                Button(localization.localized(.reset), role: .destructive) {
                    resetToDefault()
                }
                Button(localization.localized(.cancel), role: .cancel) {}
            } message: {
                Text(localization.localized(.holidaySourceResetMessage))
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
    }

    private func validateURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              let urlObj = URL(string: trimmed),
              let scheme = urlObj.scheme,
              ["https", "http"].contains(scheme.lowercased()) else {
            isValidURL = false
            return
        }

        isValidURL = true
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

                #if DEBUG
                print("[HolidaySourceSettings] downloadWithFallback returned URL =", savedURL)
                print("[HolidaySourceSettings] data size =", data.count)
                #endif

                // 3. 验证 ICS 内容（包括 VEVENT 检查）
                try downloadService.validateICSContent(data)

                // 4. 解析 ICS 以确认可以提取出节假日事件
                let parseService = ICSParseService()
                let events = try parseService.parse(data: data, region: region, sourceURL: savedURL)

                #if DEBUG
                print("[HolidaySourceSettings] parsed events count =", events.count)
                #endif

                // 5. 确保至少解析出一个事件才允许保存
                guard !events.isEmpty else {
                    throw EnhancedICSError.noEvents
                }

                // 6. 保存 URL（保存实际成功的 URL）
                try subscriptionManager.updateURL(for: region, newURL: savedURL)

                #if DEBUG
                print("[HolidaySourceSettings] URL updated in subscriptionManager")
                #endif

                // 7. 成功后自动同步
                await subscriptionManager.syncAllEnabled()

                logSaveSuccess(savedURL)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                #if DEBUG
                print("[HolidaySourceSettings] save error =", error.localizedDescription)
                #endif
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
        #if DEBUG
        print("[HolidaySourceEditView] downloadWithFallback started")
        print("[HolidaySourceEditView] trying URL =", url.absoluteString)
        #endif

        do {
            let data = try await downloadService.download(from: url, region: regionName, host: host)
            
            // 验证 ICS 内容（包括 VEVENT 检查）
            try downloadService.validateICSContent(data)
            
            #if DEBUG
            print("[HolidaySourceEditView] initial download succeeded and validated")
            #endif
            return (data, url.absoluteString)
        } catch EnhancedICSError.invalidHTTPStatus(let statusCode) where statusCode == 500 {
            // HTTP 500 时尝试 fallback 到 clean URL
            #if DEBUG
            print("[HolidaySourceEditView] HTTP 500, trying fallback to clean URL...")
            #endif

            // 获取对应地区的 clean URL
            let cleanSources = HolidayRecommendedSources.sources(for: region)
            guard let cleanSource = cleanSources.first(where: { $0.isCleanVersion }) else {
                // 没有 clean URL，直接抛出错误
                #if DEBUG
                print("[HolidaySourceEditView] no clean URL available for fallback")
                #endif
                throw EnhancedICSError.invalidHTTPStatus(statusCode)
            }

            guard let cleanURL = URL(string: cleanSource.urlString) else {
                throw EnhancedICSError.invalidURL
            }

            #if DEBUG
            print("[HolidaySourceEditView] Fallback URL:", cleanURL.absoluteString)
            #endif

            let data = try await downloadService.download(from: cleanURL, region: regionName, host: host)
            
            // 验证 clean URL 的 ICS 内容（包括 VEVENT 检查）
            // 如果 clean URL 没有事件，抛出错误而不是保存
            try downloadService.validateICSContent(data)
            
            #if DEBUG
            print("[HolidaySourceEditView] fallback download succeeded and validated")
            #endif
            return (data, cleanURL.absoluteString)
        }
    }

    private func resetToDefault() {
        subscriptionManager.resetToDefaultURL(for: region)
        urlString = subscription?.urlString ?? ""
        validateURL(urlString)
    }

    private func applyRecommendedSource() {
        guard let source = selectedRecommendedSource else { return }
        urlString = source.urlString
        validateURL(urlString)
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

            #if DEBUG
            print("[HolidaySync] actual download URL =", url.absoluteString)
            print("[HolidaySync] region =", region.rawValue)
            #endif

            let downloadService = ICSDownloadService()
            let parseService = ICSParseService()

            let host = url.host ?? ""
            let regionName = region.localizedKey
            let data = try await downloadService.download(from: url, region: regionName, host: host)

            #if DEBUG
            print("[HolidaySync] download succeeded, data size =", data.count)
            #endif

            // 验证 ICS 内容
            try downloadService.validateICSContent(data)

            let events = try parseService.parse(data: data, region: region, sourceURL: testURLString)

            #if DEBUG
            print("[HolidaySync] parsed holidays count =", events.count)
            if let firstEvent = events.first {
                print("[HolidaySync] first holiday =", firstEvent.name, "on", firstEvent.date)
            }
            #endif

            if events.isEmpty {
                errorMessage = localization.localized(.holidaySourceNoEvents)
            } else {
                errorMessage = String(format: localization.localized(.holidaySourceTestSuccess), events.count)
            }
            showError = true

        } catch {
            #if DEBUG
            print("[HolidaySync] error =", error.localizedDescription)
            #endif
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

#Preview {
    NavigationStack {
        HolidaySourceSettingsView(
            viewModel: HolidaySubscriptionSettingsViewModel(
                subscriptionManager: HolidaySubscriptionManager()
            )
        )
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
