import SwiftUI
import SwiftData
import Combine

struct CalculatorView: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @State private var grossBaseText: String = ""
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0

    @State private var hourlyRate: String = ""
    @State private var showValidation: Bool = false
    @State private var dateMode: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var selectedStartTime: Date = CalculatorView.nextQuarter(from: Date())
    @State private var selectedEndTime: Date = CalculatorView.nextQuarter(from: Date()).addingTimeInterval(2 * 60 * 60)
    @State private var hasTipsOnHome: Bool = false

    @State private var showAcceptedAlert: Bool = false
    @State private var acceptedBlock: Block? = nil
    @State private var currentTime: Date = Date()

    @EnvironmentObject private var mileageTracker: MileageTracker

    var body: some View {
        NavigationStack {
            Form {
                Section("Calculator") {
                    VStack(spacing: 16) {
                        HStack(spacing: 4) {
                            if !grossBaseText.isEmpty {
                                Text("$")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Gross payout ($)", text: $grossBaseText)
                                .keyboardType(.decimalPad)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemFill))
                            .frame(height: 60)
                            .overlay(
                                HStack(spacing: 24) {
                                    pickerPill(title: "Hours", value: $selectedHours, range: 0..<9)
                                        .frame(maxWidth: .infinity)
                                    pickerPill(title: "Minutes", value: $selectedMinutes, range: [0, 15, 30, 45])
                                        .frame(maxWidth: .infinity)
                                    Button(action: computeHourly) {
                                        Text("Compute")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .fixedSize()
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 18)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal)
                            )

                        Divider()
                            .padding(.horizontal, -16)

                        HStack {
                            Label("$/hr", systemImage: "dollarsign.circle")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(hourlyRate.isEmpty ? "—" : hourlyRate)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }

                        if showValidation {
                            Text("Please enter a valid amount and select a duration greater than 0 minutes.")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Block Date") {
                    Picker("When", selection: $dateMode) {
                        Text("Today").tag(0)
                        Text("Future").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if dateMode == 1 {
                        DatePicker("Select date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    HStack {
                        HStack {
                            Text("Start time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: Binding(get: { selectedStartTime }, set: startTimeChanged), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        Spacer()
                        HStack {
                            DatePicker("", selection: Binding(get: { selectedEndTime }, set: endTimeChanged), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            Text("End time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Tips") {
                    Toggle("Has tips", isOn: $hasTipsOnHome)
                }

                Button {
                    acceptBlock()
                } label: {
                    Text("Accept Block")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .listRowBackground(Color.clear)

                if !activeBlocks.isEmpty {
                    Section("Active Blocks") {
                        ForEach(activeBlocks, id: \.id) { block in
                            NavigationLink(destination: BlockDetailView(block: block)) {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(block.date, style: .date)
                                            .font(.body)
                                        Text("\(blockTimeFormatter.string(from: startDate(for: block))) – \(blockTimeFormatter.string(from: endDate(for: block)))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(durationText(for: block.durationMinutes))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
                                            Text("Tracking: \(String(format: "%.2f", mileageTracker.currentMiles)) mi")
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                        } else {
                                            VStack(alignment: .leading, spacing: 4) {
                                                let start = startDate(for: block)
                                                let minutesUntilStart = max(0, Int(start.timeIntervalSince(currentTime) / 60))
                                                if start > currentTime {
                                                    Text("Starting in \(minutesUntilStart) minute\(minutesUntilStart == 1 ? "" : "s")")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                } else {
                                                    Text("Active")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Button("Start GPS tracking") {
                                                    mileageTracker.requestAuthorization()
                                                    mileageTracker.startTracking(for: block.id)
                                                }
                                                .font(.caption2)
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.mini)
                                                .buttonBorderShape(.capsule)
                                                .disabled(!mileageTracker.canStartTracking)
                                                if !mileageTracker.canStartTracking {
                                                    Text("Enable location access in Settings to track miles.")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if !upcomingBlocks.isEmpty {
                    Section("Upcoming Blocks") {
                        ForEach(upcomingBlocks, id: \.id) { block in
                            NavigationLink(destination: BlockDetailView(block: block)) {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                    Text(block.date, style: .date)
                                        .font(.body)
                                    Text("\(blockTimeFormatter.string(from: startDate(for: block))) – \(blockTimeFormatter.string(from: endDate(for: block)))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(durationText(for: block.durationMinutes))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(block.status.displayName)
                                    .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 0, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("FlexErrn")
            .keyboardDoneToolbar()
            .alert("Block accepted", isPresented: $showAcceptedAlert) {
                Button("View in Log") { selectedTab = 1 }
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can add miles, tips, and expenses in the Log.")
            }
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { value in
            currentTime = value
        }
        .onChange(of: selectedDate) { newDate in
            selectedStartTime = combine(date: newDate, time: selectedStartTime)
            selectedEndTime = combine(date: newDate, time: selectedEndTime)
        }
        .onChange(of: selectedHours) { _ in
            syncEndToDuration()
        }
        .onChange(of: selectedMinutes) { _ in
            syncEndToDuration()
        }
    }

    @ViewBuilder
    private func pickerPill<T: Hashable, C: RandomAccessCollection>(title: String, value: Binding<T>, range: C) -> some View where C.Element == T, C.Element: Hashable {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("\(title)", selection: value) {
                ForEach(range, id: \.self) { item in
                    Text(String(describing: item)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func computeHourly() {
        guard let gross = Decimal(string: grossBaseText), gross >= 0 else { showValidation = true; return }
        let totalMinutes = selectedHours * 60 + selectedMinutes
        guard totalMinutes > 0 else { showValidation = true; return }

        let hrs = Decimal(totalMinutes) / 60
        let hourly = (hrs == 0) ? 0 : (gross / hrs)
        hourlyRate = formatCurrency(hourly)
        showValidation = false
    }

    private func acceptBlock() {
        guard let gross = Decimal(string: grossBaseText), gross >= 0 else { showValidation = true; return }
        let totalMinutes = selectedHours * 60 + selectedMinutes
        guard totalMinutes > 0 else { showValidation = true; return }

        let rate = settings.first?.irsMileageRate ?? 0.70
        let blockDate = (dateMode == 0) ? Date() : selectedDate
        let startDate = combine(date: blockDate, time: selectedStartTime)
        let endDate = combine(date: blockDate, time: selectedEndTime)
        let block = Block(date: blockDate, durationMinutes: totalMinutes, grossBase: gross, irsRateSnapshot: rate, startTime: startDate, endTime: endDate)
        block.hasTips = hasTipsOnHome
        block.auditEntries.append(AuditEntry(action: AuditAction.created, note: "Block accepted from calculator"))
        context.insert(block)
        NotificationManager.shared.scheduleBlockReminders(for: block)
        try? context.save()
        acceptedBlock = block
        showAcceptedAlert = true
        grossBaseText = ""
        selectedHours = 0
        selectedMinutes = 0
        hourlyRate = ""
        dateMode = 0
        selectedDate = Date()
        resetTimePickers()
        hasTipsOnHome = false
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private var upcomingBlocks: [Block] {
        let now = Date()
        return blocks
            .filter { startDate(for: $0) > now }
            .sorted { startDate(for: $0) < startDate(for: $1) }
    }

    private var activeBlocks: [Block] {
        let now = Date()
        let window = now.addingTimeInterval(45 * 60)
        return blocks
            .filter { block in
                let start = startDate(for: block)
                let end = endDate(for: block)
                return start <= window && end > now
            }
            .sorted { startDate(for: $0) < startDate(for: $1) }
    }

    private func startDate(for block: Block) -> Date {
        block.startTime ?? block.date
    }

    private func endDate(for block: Block) -> Date {
        if let end = block.endTime {
            return end
        }
        let start = startDate(for: block)
        let duration = max(1, block.durationMinutes)
        return start.addingTimeInterval(TimeInterval(duration * 60))
    }

    @Query(sort: [SortDescriptor(\Block.date)]) private var blocks: [Block]

    private func durationText(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        } else {
            return "\(minutes)m"
        }
    }

    private func startTimeChanged(_ newValue: Date) {
        selectedStartTime = combine(date: selectedDate, time: newValue)
        syncDurationToTimeRange()
        syncEndToDuration()
    }

    private func endTimeChanged(_ newValue: Date) {
        selectedEndTime = combine(date: selectedDate, time: newValue)
        syncDurationFromTimeRange()
    }

    private func syncDurationToTimeRange() {
        let diff = Int(max(1, selectedEndTime.timeIntervalSince(selectedStartTime) / 60))
        selectedHours = diff / 60
        selectedMinutes = diff % 60
    }

    private func syncEndToDuration() {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        selectedEndTime = selectedStartTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    private func syncDurationFromTimeRange() {
        syncDurationToTimeRange()
    }

    private func resetTimePickers() {
        let nextStart = CalculatorView.nextQuarter(from: Date())
        selectedStartTime = combine(date: Date(), time: nextStart)
        selectedEndTime = nextStart.addingTimeInterval(TimeInterval(max(1, selectedHours * 60 + selectedMinutes) * 60))
    }

    private static func nextQuarter(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = components.minute else { return date }
        let remainder = minute % 15
        let delta = remainder == 0 ? 0 : (15 - remainder)
        return calendar.date(byAdding: .minute, value: delta, to: date) ?? date
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents) ?? date
    }

}
