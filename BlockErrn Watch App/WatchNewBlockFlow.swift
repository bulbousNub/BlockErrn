import SwiftUI

struct WatchNewBlockFlow: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var selectedDate = Date()
    @State private var startTime = Self.nextQuarterHour()
    @State private var endTime = Self.nextQuarterHour().addingTimeInterval(3600 * 3.5)
    @State private var basePay: Double = 75.0

    var body: some View {
        NavigationStack {
            VStack {
                switch step {
                case 0: dateStep
                case 1: startTimeStep
                case 2: endTimeStep
                case 3: basePayStep
                case 4: confirmStep
                default: EmptyView()
                }
            }
            .navigationTitle("New Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step 1: Date

    private var dateStep: some View {
        VStack(spacing: 8) {
            Text("Date")
                .font(.headline)

            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()

            nextButton
        }
        .padding(.horizontal)
    }

    // MARK: - Step 2: Start Time

    private var startTimeStep: some View {
        VStack(spacing: 8) {
            Text("Start Time")
                .font(.headline)

            DatePicker(
                "Start",
                selection: $startTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            HStack {
                backButton
                nextButton
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Step 3: End Time

    private var endTimeStep: some View {
        VStack(spacing: 8) {
            Text("End Time")
                .font(.headline)

            DatePicker(
                "End",
                selection: $endTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            HStack {
                backButton
                nextButton
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Step 4: Base Pay

    private var basePayStep: some View {
        VStack(spacing: 6) {
            Text(payString)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.green)

            HStack(spacing: 8) {
                Button { basePay = max(0, basePay - 5) } label: {
                    Text("- $5").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { basePay += 5 } label: {
                    Text("+ $5").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                backButton
                nextButton
            }
        }
        .padding(.horizontal)
        .focusable()
        .digitalCrownRotation(
            $basePay,
            from: 0,
            through: 500,
            by: 0.25,
            sensitivity: .medium
        )
    }

    // MARK: - Step 5: Confirm

    private var confirmStep: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Confirm")
                    .font(.headline)

                VStack(spacing: 4) {
                    summaryRow("Date", WatchFormatters.mediumDate.string(from: selectedDate))
                    summaryRow("Start", WatchFormatters.timeString(startTime))
                    summaryRow("End", WatchFormatters.timeString(endTime))
                    summaryRow("Duration", computedDuration)
                    summaryRow("Base Pay", payString)
                }

                HStack {
                    backButton

                    Button {
                        createBlock()
                    } label: {
                        Text("Create")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private var payString: String {
        WatchFormatters.currency.string(from: NSNumber(value: basePay)) ?? "$0.00"
    }

    private var combinedStart: Date {
        combineDateAndTime(date: selectedDate, time: startTime)
    }

    private var combinedEnd: Date {
        let rawEnd = combineDateAndTime(date: selectedDate, time: endTime)
        // Handle overnight blocks (end time before start time means next day)
        if rawEnd <= combinedStart {
            return Calendar.current.date(byAdding: .day, value: 1, to: rawEnd) ?? rawEnd
        }
        return rawEnd
    }

    private var computedDuration: String {
        let minutes = max(1, Int(combinedEnd.timeIntervalSince(combinedStart) / 60))
        return WatchFormatters.durationString(minutes: minutes)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private var nextButton: some View {
        Button {
            withAnimation { step += 1 }
        } label: {
            Text("Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var backButton: some View {
        Button {
            withAnimation { step -= 1 }
        } label: {
            Image(systemName: "chevron.left")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Create Block

    private func createBlock() {
        let isoFormatter = ISO8601DateFormatter()
        let params: [String: String] = [
            "date": isoFormatter.string(from: selectedDate),
            "startTime": isoFormatter.string(from: combinedStart),
            "endTime": isoFormatter.string(from: combinedEnd),
            "grossBase": String(format: "%.2f", basePay)
        ]
        sessionManager.sendCommand(.createBlock, params: params)
        dismiss()
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? date
    }

    /// Rounds the current time up to the next 15-minute interval.
    /// e.g. 9:47 → 10:00, 9:00 → 9:00 (already on boundary), 9:01 → 9:15
    private static func nextQuarterHour() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let remainder = minute % 15
        if remainder == 0 { return now }
        let minutesToAdd = 15 - remainder
        return calendar.date(byAdding: .minute, value: minutesToAdd, to: now) ?? now
    }
}
