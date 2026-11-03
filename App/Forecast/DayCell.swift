import SwiftUI
import ForecastKit

/// One activity on one day: weekday, then label + score (or "No data"), plus a ★ on the best day.
/// The label text always accompanies the colour (FR-015).
struct DayCell: View {
    let day: DaySuitability
    let isBestDay: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(Formatting.shortWeekday(day.date))
                .font(.caption.weight(.semibold))
            switch day.result {
            case let .scored(score, label, _):
                Text(label.title)
                    .font(.caption)
                Text(score, format: .number)
                    .font(.title3.weight(.bold).monospacedDigit())
            case .noData:
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isBestDay {
                Label("Best day", systemImage: "star.fill")
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .frame(minWidth: 64)
        .background(background, in: .rect(cornerRadius: 10))
        .overlay {
            if isBestDay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(.orange, lineWidth: 2)
            }
        }
    }

    private var background: Color {
        if case let .scored(_, label, _) = day.result {
            label.color.opacity(0.25)
        } else {
            Color.secondary.opacity(0.12)
        }
    }
}

#if DEBUG
#Preview {
    let skiing = PreviewData.ranking.rankings[0]
    return HStack {
        ForEach(skiing.days.prefix(3), id: \.date) { day in
            DayCell(day: day, isBestDay: day.date == skiing.bestDay)
        }
    }
}
#endif
