import SwiftUI
import ForecastKit

/// Sheet for one activity on one day: rating, reasons, then every weather factor in the
/// user's units with "—" for missing values (contracts/ui.md › Day detail, FR-008, FR-016).
struct DayDetailView: View {
    let day: DaySuitability
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    rating
                } header: {
                    Text(Formatting.longDate(day.date))
                }

                Section("Why") {
                    switch day.result {
                    case let .scored(_, _, reasons):
                        ForEach(reasons, id: \.self) { reason in
                            Label(reason.detail.text, systemImage: icon(for: reason.kind))
                        }
                    case .noData:
                        Text("A value this activity needs is missing from the forecast.")
                    }
                }

                Section("Weather") {
                    let weather = day.weather
                    let minTemperature = Formatting.temperature(weather.temperatureMin)
                    let maxTemperature = Formatting.temperature(weather.temperatureMax)
                    LabeledContent("Min / max temperature", value: "\(minTemperature) / \(maxTemperature)")
                    let precipitation = Formatting.rainfall(weather.precipitation)
                    let probability = Formatting.percent(weather.precipitationProbability)
                    LabeledContent("Precipitation", value: "\(precipitation) (\(probability))")
                    LabeledContent("Snowfall", value: Formatting.snow(weather.snowfall))
                    LabeledContent("Snow depth", value: Formatting.snow(weather.snowDepth))
                    let wind = Formatting.windSpeed(weather.windSpeedMax)
                    let gusts = Formatting.windSpeed(weather.windGustsMax)
                    LabeledContent("Wind / gusts", value: "\(wind) / \(gusts)")
                    LabeledContent("Sunshine", value: Formatting.hours(weather.sunshine))
                }

                if day.activity == .surfing {
                    Section {
                        Text(Formatting.surfingFootnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(day.activity.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label(day.activity.title, systemImage: day.activity.symbolName)
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        // Escape closes the sheet with an iPad hardware keyboard (specs/003 FR-008).
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    @ViewBuilder
    private var rating: some View {
        switch day.result {
        case let .scored(score, label, _):
            HStack {
                Text(label.title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(score, format: .number)
                    .font(.title2.weight(.bold).monospacedDigit())
            }
            .listRowBackground(label.color.opacity(0.25))
        case .noData:
            Text("No data")
                .font(.title2.weight(.semibold))
        }
    }

    private func icon(for kind: Reason.Kind) -> String {
        switch kind {
        case .cap: "exclamationmark.octagon"
        case .negative: "hand.thumbsdown"
        case .positive: "hand.thumbsup"
        }
    }
}

#Preview("Rainy outdoor day") {
    let outdoor = PreviewData.ranking.rankings.first { $0.activity == .outdoorSightseeing }!
    return DayDetailView(day: outdoor.days[1])
}

#Preview("Surfing, thunderstorm") {
    let surfing = PreviewData.ranking.rankings.first { $0.activity == .surfing }!
    return DayDetailView(day: surfing.days[3])
}

#Preview("No data") {
    let outdoor = PreviewData.ranking.rankings.first { $0.activity == .outdoorSightseeing }!
    return DayDetailView(day: outdoor.days[5])
}
