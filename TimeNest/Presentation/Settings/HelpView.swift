import SwiftUI
import UIKit

private enum HelpLayout {
    static let horizontalPadding: CGFloat = TimeNestTheme.externalPadding
    static let verticalSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 26
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 15
    static let iconSize: CGFloat = 34
}

private struct HelpFAQItem: Identifiable {
    let questionKey: LocalizedString
    let answerKey: LocalizedString

    var id: String { questionKey.rawValue }
}

private enum HelpFAQCategory: String, CaseIterable, Identifiable, Hashable {
    case events
    case views
    case holidays
    case shifts
    case ads
    case privacy

    var id: String { rawValue }

    var titleKey: LocalizedString {
        switch self {
        case .events: .helpCategoryEvents
        case .views: .helpCategoryViews
        case .holidays: .helpCategoryHolidays
        case .shifts: .helpCategoryShifts
        case .ads: .helpCategoryAds
        case .privacy: .helpCategoryPrivacy
        }
    }

    var systemImage: String {
        switch self {
        case .events: "calendar.badge.plus"
        case .views: "rectangle.3.group"
        case .holidays: "calendar.badge.exclamationmark"
        case .shifts: "clock.badge.checkmark"
        case .ads: "rectangle.badge.checkmark"
        case .privacy: "lock.shield"
        }
    }

    var items: [HelpFAQItem] {
        switch self {
        case .events:
            [
                HelpFAQItem(questionKey: .helpEventsAddQuestion, answerKey: .helpEventsAddAnswer),
                HelpFAQItem(questionKey: .helpEventsAllDayQuestion, answerKey: .helpEventsAllDayAnswer),
                HelpFAQItem(questionKey: .helpEventsEditDeleteQuestion, answerKey: .helpEventsEditDeleteAnswer)
            ]
        case .views:
            [
                HelpFAQItem(questionKey: .helpViewsSwitchQuestion, answerKey: .helpViewsSwitchAnswer),
                HelpFAQItem(questionKey: .helpViewsTodayQuestion, answerKey: .helpViewsTodayAnswer),
                HelpFAQItem(questionKey: .helpViewsMoveQuestion, answerKey: .helpViewsMoveAnswer)
            ]
        case .holidays:
            [
                HelpFAQItem(questionKey: .helpHolidaysShowQuestion, answerKey: .helpHolidaysShowAnswer),
                HelpFAQItem(questionKey: .helpHolidaysMissingQuestion, answerKey: .helpHolidaysMissingAnswer),
                HelpFAQItem(questionKey: .helpHolidaysLanguageQuestion, answerKey: .helpHolidaysLanguageAnswer)
            ]
        case .shifts:
            [
                HelpFAQItem(questionKey: .helpShiftsAddQuestion, answerKey: .helpShiftsAddAnswer),
                HelpFAQItem(questionKey: .helpShiftsMultipleQuestion, answerKey: .helpShiftsMultipleAnswer),
                HelpFAQItem(questionKey: .helpShiftsReplaceQuestion, answerKey: .helpShiftsReplaceAnswer),
                HelpFAQItem(questionKey: .helpShiftsChangeTimeQuestion, answerKey: .helpShiftsChangeTimeAnswer),
                HelpFAQItem(questionKey: .helpShiftsDifferenceQuestion, answerKey: .helpShiftsDifferenceAnswer),
                HelpFAQItem(questionKey: .helpShiftsRecordQuestion, answerKey: .helpShiftsRecordAnswer),
                HelpFAQItem(questionKey: .helpShiftsOvernightQuestion, answerKey: .helpShiftsOvernightAnswer),
                HelpFAQItem(questionKey: .helpShiftsStatisticsQuestion, answerKey: .helpShiftsStatisticsAnswer),
                HelpFAQItem(questionKey: .helpShiftsStatisticsMissingQuestion, answerKey: .helpShiftsStatisticsMissingAnswer)
            ]
        case .ads:
            [
                HelpFAQItem(questionKey: .helpAdsAboutQuestion, answerKey: .helpAdsAboutAnswer),
                HelpFAQItem(questionKey: .helpAdsRestoreQuestion, answerKey: .helpAdsRestoreAnswer),
                HelpFAQItem(questionKey: .helpAdsRestoreFailedQuestion, answerKey: .helpAdsRestoreFailedAnswer)
            ]
        case .privacy:
            [
                HelpFAQItem(questionKey: .helpPrivacyStorageQuestion, answerKey: .helpPrivacyStorageAnswer),
                HelpFAQItem(questionKey: .helpPrivacyAccountQuestion, answerKey: .helpPrivacyAccountAnswer),
                HelpFAQItem(questionKey: .helpPrivacyDeleteAppQuestion, answerKey: .helpPrivacyDeleteAppAnswer)
            ]
        }
    }
}

struct HelpView: View {
    private static let contactEmail = "songlabs.dev@gmail.com"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationManager

    @State private var navigationPath: [HelpFAQCategory] = []
    @State private var showingMailFallback = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: HelpLayout.verticalSpacing) {
                    Text(localization.localized(.helpFrequentlyAskedQuestions))
                        .font(.headline)
                        .foregroundColor(SettingsModalSurface.primaryText)

                    categoryCard
                }
                .padding(.horizontal, HelpLayout.horizontalPadding)
                .padding(.vertical, HelpLayout.verticalSpacing)
            }
            .background(SettingsModalSurface.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if navigationPath.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(localization.localized(.done)) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Text(localization.localized(.helpTitle))
                            .font(TimeNestTheme.Fonts.popupTitle)
                            .foregroundColor(SettingsModalSurface.primaryText)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(localization.localized(.helpContact)) {
                            openContactEmail()
                        }
                    }
                }
            }
            .navigationDestination(for: HelpFAQCategory.self) { category in
                HelpFAQCategoryView(category: category)
                    .environmentObject(localization)
            }
        }
        .tint(.accentColor)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(localization.localized(.helpMailUnavailableTitle), isPresented: $showingMailFallback) {
            Button(localization.localized(.helpCopyEmail)) {
                UIPasteboard.general.string = Self.contactEmail
            }
            Button(localization.localized(.cancel), role: .cancel) {}
        } message: {
            Text(String(
                format: localization.localized(.helpMailUnavailableMessage),
                Self.contactEmail
            ))
        }
    }

    private var categoryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(HelpFAQCategory.allCases.enumerated()), id: \.element.id) { index, category in
                NavigationLink(value: category) {
                    HStack(spacing: 12) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: HelpLayout.iconSize, height: HelpLayout.iconSize)
                            .background(Color.accentColor.opacity(0.12), in: Circle())

                        Text(localization.localized(category.titleKey))
                            .font(.body)
                            .foregroundColor(SettingsModalSurface.primaryText)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(SettingsModalSurface.secondaryText)
                    }
                    .padding(.horizontal, HelpLayout.rowHorizontalPadding)
                    .padding(.vertical, HelpLayout.rowVerticalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < HelpFAQCategory.allCases.count - 1 {
                    Divider()
                        .padding(.leading, HelpLayout.rowHorizontalPadding + HelpLayout.iconSize + 12)
                }
            }
        }
        .background(SettingsModalSurface.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: HelpLayout.cardCornerRadius, style: .continuous))
    }

    private func openContactEmail() {
        guard let url = contactURL else {
            showingMailFallback = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                showingMailFallback = true
            }
        }
    }

    private var contactURL: URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let body = String(
            format: localization.localized(.helpContactEmailBody),
            version,
            build,
            UIDevice.current.systemVersion,
            localization.currentLocale.identifier
        )

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: localization.localized(.helpContactEmailSubject)),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

private struct HelpFAQCategoryView: View {
    let category: HelpFAQCategory

    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(spacing: HelpLayout.verticalSpacing) {
                ForEach(category.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(item.questionKey))
                            .font(.headline)
                            .foregroundColor(SettingsModalSurface.primaryText)

                        Text(localization.localized(item.answerKey))
                            .font(.body)
                            .foregroundColor(SettingsModalSurface.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(HelpLayout.rowHorizontalPadding)
                    .background(SettingsModalSurface.sectionBackground)
                    .clipShape(RoundedRectangle(cornerRadius: HelpLayout.cardCornerRadius, style: .continuous))
                }
            }
            .padding(HelpLayout.horizontalPadding)
        }
        .background(SettingsModalSurface.background)
        .navigationTitle(localization.localized(category.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
