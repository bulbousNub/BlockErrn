import SwiftUI

struct WatchNewBlockFlow: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600 * 3.5)
    @State private var basePay: Double = 75.0

    private let payStep: Double = 0.50
    private let minPay: Double = 0.00
    private let maxPay: Double = 999.50

    var body: some View {
        NavigationStack {
            TabView(selection: $step) {
                dateStep.tag(0)
                startTimeStep.tag(1)
                endTimeStep.tag(2)
                basePayStep.tag(3)
                confirmStep.tag(4)
            }
            .tabViewStyle(.verticalPage)
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
        VStack(spacing: 8) {
            Text("Base Pay")
                .font(.headline)

            Text(payString)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .focusable()
                .digitalCrownRotation(
                    $basePay,
                    from: minPay,
                    through: maxPay,
                    by: payStep,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Text("Use Digital Crown")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                backButton
                nextButton
            }
        }
        .padding(.horizontal)
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

    private var computedDuration: String {
        let combinedStart = combineDateAndTime(date: selectedDate, time: startTime)
        let combinedEnd = combineDateAndTime(date: selectedDate, time: endTime)
        var end = combinedEnd
        if end <= combinedStart {
            end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
        }
        let minutes = max(1, Int(end.timeIntervalSince(combinedStart) / 60))
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
        let combinedStart = combineDateAndTime(date: selectedDate, time: startTime)
        let combinedEnd = combineDateAndTime(date: selectedDate, time: endTime)

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
}
