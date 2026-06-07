import SwiftUI

struct HolidaySubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: HolidaySubscriptionSettingsViewModel
    @ObservedObject private var tabBarVisibility = TabBarVisibilityState.shared

    @State private var showingSyncError = false
    @State private var showingSyncResult = false
    @State private var syncResultTitle = ""
    @State private var syncResultMessage = ""
    @State private var didHideTabBar = false

    init() {
        _viewModel = StateObject(wrappedValue: HolidaySubscriptionSettingsViewModel(subscriptionManager: .shared))
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
            Text(localization.localized(.holidaySubscriptionSettingsTitle))
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeaderView

                List {
                    // 同步状态和刷新按钮
                    Section {
                        HStack {
                            Spacer()

                            if viewModel.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button {
                                    Task {
                                        let result = await viewModel.syncAll()
                                        await MainActor.run {
                                            if result.isSuccess {
                                                syncResultTitle = localization.localized(.holidaySubscriptionSyncSuccessTitle)
                                                syncResultMessage = localization.localized(.holidaySubscriptionSyncSuccessMessage)
                                                showingSyncResult = true
                                            } else if let error = result.error {
                                                syncResultTitle = localization.localized(.holidaySubscriptionSyncFailedTitle)
                                                syncResultMessage = error.localizedDescription
                                                showingSyncResult = true
                                            }
                                        }
                                    }
                                } label: {
                                    Text(localization.localized(.holidaySubscriptionRefresh))
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .disabled(viewModel.isSyncing)
                            }
                        }
                    }

                    // 订阅列表
                    if viewModel.allAvailableSubscriptions.isEmpty {
                        ContentUnavailableView {
                            Label("holiday_subscription.no_subscriptions", systemImage: "calendar.badge.exclamationmark")
                        } description: {
                            Text(localization.localized(.holidaySubscriptionNoSubscriptionsDescription))
                        }
                    } else {
                        Section {
                            ForEach(viewModel.allAvailableSubscriptions) { subscription in
                                NavigationLink {
                                    HolidaySourceEditView(
                                        region: subscription.region,
                                        subscriptionManager: viewModel.subscriptionManager
                                    )
                                    .environmentObject(localization)
                                } label: {
                                    SubscriptionRowView(
                                        subscription: subscription,
                                        isEnabled: viewModel.isEnabled(subscription.region),
                                        canToggle: viewModel.canToggle(subscription.region),
                                        onToggle: {
                                            viewModel.toggleSubscription(subscription.region)
                                        }
                                    )
                                }
                            }
                        } header: {
                            Text(localization.localized(.holidaySubscriptionListHeader))
                        } footer: {
                            Text(localization.localized(.holidaySubscriptionMaxLimitNote))
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
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
        }
        .onDisappear {
            if didHideTabBar {
                tabBarVisibility.show()
                didHideTabBar = false
            }
        }
        .alert(syncResultTitle, isPresented: $showingSyncResult) {
            Button(localization.localized(.ok), role: .cancel) {}
        } message: {
            Text(syncResultMessage)
        }
        .alert(localization.localized(.holidaySubscriptionSyncError), isPresented: $showingSyncError) {
        } message: {
            Text(viewModel.lastSyncError?.localizedDescription ?? "")
        }
        .onChange(of: viewModel.isSyncing) { _, newValue in
            if !newValue {
                // 同步完成后检查是否有错误
                if let _ = viewModel.lastSyncError {
                    showingSyncError = true
                }
            }
        }
        .environmentObject(viewModel.subscriptionManager)
    }
}

// MARK: - SubscriptionRowView

struct SubscriptionRowView: View {
    let subscription: HolidaySubscription
    let isEnabled: Bool
    let canToggle: Bool
    let onToggle: () -> Void

    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：复选框（仅圆圈区域可点击切换）
            Button(action: {
                if canToggle {
                    onToggle()
                }
            }) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)

            // 中间：订阅信息
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(subscription.displayNameKey))
                    .foregroundColor(.primary)
                    .font(.body)

                // 同步状态
                HStack(spacing: 4) {
                    syncStatusIcon
                    Text(syncStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(canToggle ? 1.0 : 0.6)
    }
    
    private var syncStatusIcon: some View {
        Image(systemName: iconForStatus(subscription.syncStatus))
            .foregroundColor(forStatus(subscription.syncStatus))
    }
    
    private func iconForStatus(_ status: SyncStatus) -> String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .neverSynced:
            return "arrow.triangle.2.circle.path.circle"
        }
    }
    
    private func forStatus(_ status: SyncStatus) -> Color {
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .neverSynced:
            return .orange
        }
    }
    
    private var syncStatusText: String {
        switch subscription.syncStatus {
        case .success:
            return localization.localized(.holidaySubscriptionSynced)
        case .failed:
            return localization.localized(.holidaySubscriptionSyncFailed)
        case .neverSynced:
            return localization.localized(.holidaySubscriptionNotSynced)
        }
    }
}

// MARK: - ViewModel

@MainActor
class HolidaySubscriptionSettingsViewModel: ObservableObject {
    @Published private(set) var allAvailableSubscriptions: [HolidaySubscription] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    let subscriptionManager: HolidaySubscriptionManager
    
    init(subscriptionManager: HolidaySubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        updateSubscriptions()
    }
    
    func isEnabled(_ region: HolidayRegion) -> Bool {
        subscriptionManager.subscriptions.first { $0.region == region }?.isEnabled ?? false
    }
    
    func canToggle(_ region: HolidayRegion) -> Bool {
        guard let subscription = subscriptionManager.subscriptions.first(where: { $0.region == region }) else {
            return false
        }
        
        if subscription.isEnabled {
            // 禁用时检查是否满足最小数量
            return subscriptionManager.canDisable(subscription: subscription)
        } else {
            // 启用时检查是否满足最大数量
            return subscriptionManager.canEnableMore()
        }
    }
    
    func toggleSubscription(_ region: HolidayRegion) {
        guard let subscription = subscriptionManager.subscriptions.first(where: { $0.region == region }) else {
            return
        }
        
        do {
            if subscription.isEnabled {
                try subscriptionManager.disable(subscription: subscription)
            } else {
                try subscriptionManager.enable(subscription: subscription)
            }
            updateSubscriptions()
        } catch {
            print("Toggle subscription failed: \(error)")
        }
    }
    
    func syncAll() async -> SyncResult {
        isSyncing = true
        lastSyncError = nil
        
        let result = await subscriptionManager.syncAllEnabled()
        
        isSyncing = false
        lastSyncError = result.error
        updateSubscriptions()
        
        return result
    }
    
    private func updateSubscriptions() {
        allAvailableSubscriptions = subscriptionManager.allAvailableSubscriptions
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HolidaySubscriptionSettingsView()
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
#endif
