import SwiftUI

struct WatchBlockDetailView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    let block: WatchBlockSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Time info
                VStack(spacing: 4) {
                    Text(WatchFormatters.timeRangeString(
                        start: block.startTime,
                        end: block.endTime,
                        duration: block.durationMinutes
                    ))
                    .font(.headline)

                    Text(WatchFormatters.mediumDate.string(from: block.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Pay details
                VStack(spacing: 6) {
                    detailRow("Gross", WatchFormatters.currencyString(block.grossPayoutDecimal))

                    if block.milesDecimal > 0 {
                        detailRow("Miles", WatchFormatters.milesString(block.milesDecimal))
                        detailRow("Deduction", "-\(WatchFormatters.currencyString(block.mileageDeductionDecimal))")
                    }

                    if block.additionalExpensesTotalDecimal > 0 {
                        detailRow("Expenses", "-\(WatchFormatters.currencyString(block.additionalExpensesTotalDecimal))")
                    }

                    Divider()

                    HStack {
                        Text("Profit")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(WatchFormatters.currencyString(block.totalProfitDecimal))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(block.totalProfitDecimal >= 0 ? .green : .red)
                    }
                }

                Divider()

                // Actions
                VStack(spacing: 8) {
                    if block.isEligibleForMakeActive && sessionManager.workModeBlockID != block.id {
                        Button {
                            sessionManager.sendCommand(.startBlock, blockID: block.id)
                        } label: {
                            Label("Start Block", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    if sessionManager.workModeBlockID != block.id && !block.isEligibleForMakeActive {
                        Button {
                            sessionManager.sendCommand(.makeActive, blockID: block.id)
                        } label: {
                            Label("Make Active", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Block Details")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
    }
}
