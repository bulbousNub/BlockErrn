import SwiftUI

struct WatchBlockRow: View {
    let block: WatchBlockSummary
    let isWorkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(WatchFormatters.timeRangeString(
                    start: block.startTime,
                    end: block.endTime,
                    duration: block.durationMinutes
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if isWorkMode {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Text(WatchFormatters.currencyString(block.grossPayoutDecimal))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(WatchFormatters.durationString(minutes: block.durationMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
