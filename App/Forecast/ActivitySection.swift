import SwiftUI
import ForecastKit

/// One activity: ranked header and a scrollable row of up to 7 day cells (FR-006, FR-007).
struct ActivitySection: View {
    let ranking: ActivityRanking
    /// Called when a day cell is tapped, to show its detail.
    let onSelect: (DaySuitability) -> Void

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(ranking.days, id: \.date) { day in
                        Button {
                            onSelect(day)
                        } label: {
                            DayCell(day: day, isBestDay: day.date == ranking.bestDay)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            if ranking.bestDay == nil {
                Text("No suitable day this week")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(Formatting.sectionHeader(ranking))
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
        } footer: {
            if ranking.activity == .surfing {
                Text(Formatting.surfingFootnote)
            }
        }
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(PreviewData.ranking.rankings) { ActivitySection(ranking: $0, onSelect: { _ in }) }
    }
}
#endif
