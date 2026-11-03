import SwiftUI
import ForecastKit

/// One place's week, activities in rank order (contracts/ui.md › Forecast).
struct ForecastView: View {
    @State private var model: ForecastModel
    @State private var selection: DaySelection?

    init(place: Place, service: any WeatherService) {
        _model = State(initialValue: ForecastModel(place: place, service: service))
    }

    var body: some View {
        LoadStateView(state: model.state, retry: { await model.retry() }) { ranking in
            List {
                if let subtitle = model.place.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                ForEach(ranking.rankings) { activityRanking in
                    ActivitySection(ranking: activityRanking) { day in
                        selection = DaySelection(day: day)
                    }
                }
            }
        }
        .navigationTitle(model.place.name)
        .task { await model.load() }
        .sheet(item: $selection) { selection in
            DayDetailView(day: selection.day)
        }
    }
}

/// Identifies the day whose detail sheet is shown.
private struct DaySelection: Identifiable {
    let day: DaySuitability
    var id: DaySuitability { day }
}

#if DEBUG
#Preview("Loaded") {
    NavigationStack { ForecastView(place: PreviewData.paris, service: PreviewData.service) }
}

#Preview("Loading") {
    NavigationStack { ForecastView(place: PreviewData.paris, service: PreviewData.hangingService) }
}

#Preview("Failed") {
    NavigationStack { ForecastView(place: PreviewData.paris, service: PreviewData.offlineService) }
}
#endif
