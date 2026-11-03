import SwiftUI
import ForecastKit

/// One activity: ranked header and a scrollable row of up to 7 day cells (FR-006, FR-007).
struct ActivitySection: View {
    let ranking: ActivityRanking

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(ranking.days, id: \.date) { day in
                        DayCell(day: day, isBestDay: day.date == ranking.bestDay)
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
        }
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(PreviewData.ranking.rankings) { ActivitySection(ranking: $0) }
    }
}
#endif
