import SwiftUI
import ForecastKit

/// One place's week, activities in rank order (contracts/ui.md › Forecast).
struct ForecastView: View {
    let model: ForecastModel
    @State private var selection: DaySelection?

    var body: some View {
        LoadStateView(state: model.state, retry: { await model.retry() }, content: { ranking in
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
        })
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
    NavigationStack { ForecastView(model: ForecastModel(place: PreviewData.paris, service: PreviewData.service)) }
}

#Preview("Loading") {
    NavigationStack {
        ForecastView(model: ForecastModel(place: PreviewData.paris, service: PreviewData.hangingService))
    }
}

#Preview("Failed") {
    NavigationStack {
        ForecastView(model: ForecastModel(place: PreviewData.paris, service: PreviewData.offlineService))
    }
}
#endif
