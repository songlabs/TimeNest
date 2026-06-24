import SwiftUI

private enum HolidaySubscriptionLayout {
    static let sheetCompactHeight: CGFloat = 400
    static let sheetMaximumHeightRatio: CGFloat = 0.62
    static let headerBottomPadding: CGFloat = 2
    static let rowVerticalPadding: CGFloat = 0
    static let syncButtonWidth: CGFloat = 88
    static let syncButtonHeight: CGFloat = 32
}

private struct HolidaySubscriptionCompactDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        min(
            HolidaySubscriptionLayout.sheetCompactHeight,
            context.maxDetentValue * HolidaySubscriptionLayout.sheetMaximumHeightRatio
        )
    }
}

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

    init(subscriptionManager: HolidaySubscriptionManager) {
        _viewModel = StateObject(
            wrappedValue: HolidaySubscriptionSettingsViewModel(
                subscriptionManager: subscriptionManager
            )
        )
    }

    private var customHeaderView: some View {
        HStack(spacing: 8) {
            Text(localization.localized(.holidaySubscriptionSettingsTitle))
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(SettingsModalSurface.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            if viewModel.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(
                        width: HolidaySubscriptionLayout.syncButtonWidth,
                        height: HolidaySubscriptionLayout.syncButtonHeight
                    )
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
                }
                .buttonStyle(ShiftToggleActiveButtonStyle.workAction)
                .disabled(viewModel.isSyncing)
            }

            ModalHeaderCloseButton {
                dismiss()
            }
        }
        .padding(.horizontal, TimeNestTheme.externalPadding)
        .padding(.top, TimeNestTheme.externalPadding)
        .padding(.bottom, HolidaySubscriptionLayout.headerBottomPadding)
        .background(SettingsModalSurface.background)
    }

    var body: some View {
        ZStack {
            SettingsModalSurface.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeaderView

                List {
                    // 订阅列表
                    if viewModel.allAvailableSubscriptions.isEmpty {
                        ContentUnavailableView {
                            Label(localization.localized(.holidaySubscriptionNoSubscriptions), systemImage: "calendar.badge.exclamationmark")
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
                                            Task {
                                                await viewModel.toggleSubscription(subscription.region)
                                            }
                                        }
                                    )
                                }
                            }
                        } footer: {
                            Text(localization.localized(.holidaySubscriptionMaxLimitNote))
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
            }
        }
        .background(SettingsModalSurface.background)
        .presentationDetents([.custom(HolidaySubscriptionCompactDetent.self)])
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

            Text(localization.localized(subscription.displayNameKey))
                .foregroundColor(.primary)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, HolidaySubscriptionLayout.rowVerticalPadding)
        .opacity(canToggle ? 1.0 : 0.6)
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
    
    func toggleSubscription(_ region: HolidayRegion) async {
        guard let subscription = subscriptionManager.subscriptions.first(where: { $0.region == region }) else {
            return
        }

        let shouldSyncAfterEnabling = !subscription.isEnabled && subscription.syncStatus == .neverSynced
        
        do {
            if subscription.isEnabled {
                try subscriptionManager.disable(subscription: subscription)
            } else {
                try subscriptionManager.enable(subscription: subscription)
            }
            updateSubscriptions()

            if shouldSyncAfterEnabling {
                _ = await syncAll()
            }
        } catch {
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
