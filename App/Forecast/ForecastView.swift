import SwiftUI
import ForecastKit

/// One place's week, activities in rank order (contracts/ui.md › Forecast).
/// All state lives in `model`, so a rebuild after a fold or resize keeps the loaded week and any
/// open day sheet (specs/003 FR-007, US3).
struct ForecastView: View {
    let model: ForecastModel

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
                        model.selectedDay = day
                    }
                }
            }
        })
        .navigationTitle(model.place.name)
        .task { await model.loadIfNeeded() }
        .sheet(item: daySelection) { selection in
            DayDetailView(day: selection.day)
        }
    }

    private var daySelection: Binding<DaySelection?> {
        Binding(get: { model.selectedDay.map { DaySelection(day: $0) } },
                set: { model.selectedDay = $0?.day })
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
