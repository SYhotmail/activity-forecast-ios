import SwiftUI
import ForecastKit

/// One activity: ranked header and a scrollable row of up to 7 day cells (FR-006, FR-007).
struct ActivitySection: View {
    let ranking: ActivityRanking
    /// Namespace the day sheet zooms out of on wide windows (specs/003 FR-012, research.md R5).
    let transitionNamespace: Namespace.ID
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
                        .matchedTransitionSource(id: day, in: transitionNamespace)
                        .accessibilityHint("Shows the reasons and weather for this day")
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
            Label(Formatting.sectionHeader(ranking), systemImage: ranking.activity.symbolName)
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

#Preview {
    @Previewable @Namespace var namespace
    List {
        ForEach(PreviewData.ranking.rankings) {
            ActivitySection(ranking: $0, transitionNamespace: namespace, onSelect: { _ in })
        }
    }
}
