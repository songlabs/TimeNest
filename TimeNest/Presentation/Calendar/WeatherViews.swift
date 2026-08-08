import SwiftUI

struct AppleWeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme

    let attribution: WeatherAttributionSnapshot
    var compact = true

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            AsyncImage(url: markURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .empty:
                    Text(attribution.serviceName)
                        .font(.caption2.weight(.medium))
                case .failure:
                    Text(attribution.serviceName)
                        .font(.caption2.weight(.medium))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: compact ? 96 : 120, maxHeight: compact ? 13 : 16)
            .accessibilityLabel(attribution.serviceName)

            Link(
                LocalizationManager.shared.localized(.weatherAttributionLegal),
                destination: attribution.legalPageURL
            )
            .font(compact ? .caption2 : .caption)
            .lineLimit(1)
            .accessibilityIdentifier("weather.attribution.legal")

            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather.attribution")
    }

    private var markURL: URL {
        colorScheme == .dark
            ? attribution.combinedMarkDarkURL
            : attribution.combinedMarkLightURL
    }
}

struct WeatherHeaderAttributionView: View {
    let attribution: WeatherAttributionSnapshot
    @Binding private var isMarkVisible: Bool

    init(
        attribution: WeatherAttributionSnapshot,
        isMarkVisible: Binding<Bool> = .constant(false)
    ) {
        self.attribution = attribution
        _isMarkVisible = isMarkVisible
    }

    var body: some View {
        AsyncImage(url: squareMarkURL) { phase in
            switch phase {
            case .success(let image):
                Link(destination: legalPageURL) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .accessibilityIdentifier("weather.header.attribution.mark")
                        .frame(width: 18, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(
                    "\(attribution.serviceName), \(LocalizationManager.shared.localized(.weatherAttributionLegal))"
                )
                .accessibilityIdentifier("weather.header.attribution")
                .onAppear {
                    setMarkVisible(true)
                }
            case .empty, .failure:
                hiddenPlaceholder
                    .onAppear {
                        setMarkVisible(false)
                    }
            @unknown default:
                hiddenPlaceholder
                    .onAppear {
                        setMarkVisible(false)
                    }
            }
        }
        .frame(width: 18, height: 36)
        .onDisappear {
            setMarkVisible(false)
        }
    }

    var squareMarkURL: URL {
        attribution.squareMarkURL
    }

    var legalPageURL: URL {
        attribution.legalPageURL
    }

    private var hiddenPlaceholder: some View {
        Color.clear
            .frame(width: 18, height: 36)
            .accessibilityHidden(true)
    }

    private func setMarkVisible(_ isVisible: Bool) {
        guard isMarkVisible != isVisible else { return }
        isMarkVisible = isVisible
    }
}

struct InlineWeatherUnavailableView: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "cloud.slash")
                    .font(.caption)
            }

            Text(
                LocalizationManager.shared.localized(
                    isLoading ? .weatherLoading : .weatherUnavailable
                )
            )
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("weather.unavailable")
    }
}

struct DayWeatherSection: View {
    @EnvironmentObject private var localization: LocalizationManager

    let weather: DayWeatherSnapshot?
    let isLoading: Bool
    let attribution: WeatherAttributionSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let weather {
                weatherContent(weather)
            } else {
                InlineWeatherUnavailableView(isLoading: isLoading)
                    .frame(minHeight: 54)
            }

            if let attribution {
                AppleWeatherAttributionView(attribution: attribution, compact: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(TimeNestTheme.primaryText)
        .background {
            ZStack {
                TimeNestTheme.cardBackground
                TimeNestTheme.glassCapsuleTint
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TimeNestTheme.divider.opacity(0.55))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather.day.section")
    }

    @ViewBuilder
    private func weatherContent(_ weather: DayWeatherSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: weather.symbolName)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color(uiColor: .systemBlue))
                .font(.system(size: 34, weight: .semibold))
                .shadow(
                    color: Color(uiColor: .systemGray).opacity(0.45),
                    radius: 0.75
                )
                .frame(width: 44)
                .accessibilityIdentifier("weather.day.symbol")

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    localization.localized(
                        weather.usesCurrentWeather ? .weatherCurrent : .weatherNearestHour
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    WeatherValueFormatter.temperature(
                        weather.temperatureCelsius,
                        locale: localization.currentLocale
                    )
                )
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("weather.day.temperature")
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                weatherMetric(
                    localization.localized(.weatherHigh),
                    WeatherValueFormatter.temperature(
                        weather.highTemperatureCelsius,
                        locale: localization.currentLocale,
                        compact: true
                    ),
                    identifier: "weather.day.high"
                )
                weatherMetric(
                    localization.localized(.weatherLow),
                    WeatherValueFormatter.temperature(
                        weather.lowTemperatureCelsius,
                        locale: localization.currentLocale,
                        compact: true
                    ),
                    identifier: "weather.day.low"
                )
            }
        }

        HStack(spacing: 16) {
            Label {
                Text(
                    "\(localization.localized(.weatherPrecipitation)) \(WeatherValueFormatter.percentage(weather.precipitationChance, locale: localization.currentLocale))"
                )
            } icon: {
                Image(systemName: "drop.fill")
            }
            .accessibilityIdentifier("weather.day.precipitation")

            Label {
                Text(
                    "\(localization.localized(.weatherWind)) \(WeatherValueFormatter.windSpeed(weather.windSpeedMetersPerSecond, locale: localization.currentLocale))"
                )
            } icon: {
                Image(systemName: "wind")
            }
            .accessibilityIdentifier("weather.day.wind")
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .foregroundStyle(.secondary)

        if !weather.hourly.isEmpty {
            Text(localization.localized(.weatherHourlyForecast))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(weather.hourly) { hour in
                        VStack(spacing: 4) {
                            Text(
                                WeatherValueFormatter.hour(
                                    hour.date,
                                    locale: localization.currentLocale
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Image(systemName: hour.symbolName)
                                .symbolRenderingMode(.multicolor)
                                .foregroundStyle(Color(uiColor: .systemBlue))
                                .font(.system(size: 18, weight: .semibold))
                                .shadow(
                                    color: Color(uiColor: .systemGray).opacity(0.35),
                                    radius: 0.5
                                )

                            Text(
                                WeatherValueFormatter.temperature(
                                    hour.temperatureCelsius,
                                    locale: localization.currentLocale,
                                    compact: true
                                )
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .frame(width: 54)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(height: 72)
            .accessibilityIdentifier("weather.day.hourly")
        }
    }

    private func weatherMetric(
        _ label: String,
        _ value: String,
        identifier: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityIdentifier(identifier)
    }
}
