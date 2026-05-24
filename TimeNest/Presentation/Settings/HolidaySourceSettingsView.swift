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
              scheme.lowercased() == "https" else {
            isValidURL = false
            return
        }
        
        isValidURL = true
    }
    
    private func saveURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try subscriptionManager.updateURL(for: region, newURL: trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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
        
        do {
            // 下载并解析测试
            guard let url = URL(string: subscription.urlString) else {
                throw SubscriptionManagerError.invalidURL
            }
            
            let downloadService = ICSDownloadService()
            let parseService = ICSParseService()
            
            let host = url.host ?? ""
            let regionName = region.localizedKey
            let data = try await downloadService.download(from: url, region: regionName, host: host)
            let events = try await parseService.parse(data: data, region: region, sourceURL: subscription.urlString)
            
            if events.isEmpty {
                errorMessage = localization.localized(.holidaySourceNoEvents)
            } else {
                errorMessage = String(format: localization.localized(.holidaySourceTestSuccess), events.count)
            }
            showError = true
            
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
