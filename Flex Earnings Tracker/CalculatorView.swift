import SwiftUI
import SwiftData

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

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var mileageTracker: MileageTracker

    private var activeSettings: AppSettings? {
        settings.first
    }

    private var shouldShowPlanCard: Bool {
        !(activeSettings?.hasDismissedPlanCard ?? false)
    }

    private var includePreReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.includePreReminder ?? true },
            set: { newValue in
                guard let setting = settings.first else { return }
                setting.includePreReminder = newValue
                try? context.save()
            }
        )
    }

    private var includePreReminderPreference: Bool {
        settings.first?.includePreReminder ?? true
    }

    private var reminderDescription: String {
        if includePreReminderPreference {
            return "FlexErrn will remind you 15 minutes before your block ends and once more when the block finishes so you remember to stop GPS tracking."
        } else {
            return "FlexErrn will only remind you at the scheduled block end time to stop GPS tracking."
        }
    }

    private var datePickerControlColor: Color {
        colorScheme == .light ? .primary : .accentColor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if !activeBlocks.isEmpty {
                            sectionBlockList(title: "Active blocks", blocks: activeBlocks, showStartButton: true)
                        }
                        if shouldShowPlanCard {
                            heroCard
                        }
                        earningsCard
                        scheduleCard
                        remindersCard
                        actionRow
                        if !upcomingBlocks.isEmpty {
                            sectionBlockList(title: "Upcoming blocks", blocks: upcomingBlocks, showStartButton: false)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    startTimer()
                }
            }
            .navigationTitle("FlexErrn")
            .onAppear { startTimer() }
            .onChange(of: selectedHours) { _ in
                syncEndToDuration()
            }
            .onChange(of: selectedMinutes) { _ in
                syncEndToDuration()
            }
            .alert("Block accepted", isPresented: $showAcceptedAlert) {
                Button("View in Log") {
                    selectedTab = 1
                }
                Button("Done", role: .cancel) { }
            } message: {
                Text("Add miles, tips, and expenses in the Log to finish profiling the block.")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan with confidence")
                .font(.headline)
            Text("Use the tiles below to model your next trip—the tracker handles gross, tips, mileage, and reminders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Tap Got it once you’ve reviewed the quick tips so this card can stay out of the way.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Got it") {
                    acknowledgePlanCard()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        }
        .flexErrnCardStyle()
    }

    private func acknowledgePlanCard() {
        guard let settingsInstance = activeSettings else { return }
        settingsInstance.hasDismissedPlanCard = true
        try? context.save()
    }

    private var earningsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Calculator")
                    .font(.headline)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                TextField("Gross payout", text: $grossBaseText)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .keyboardDoneToolbar()
            }
            .padding(.vertical, 8)
            Divider()
            HStack(alignment: .center, spacing: 12) {
                pickerPill(title: "Hours", value: $selectedHours, range: 0..<9)
                pickerPill(title: "Minutes", value: $selectedMinutes, range: [0, 15, 30, 45])
                Toggle(isOn: $hasTipsOnHome) {
                    Text("Has tips")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.switch)
                Spacer()
                Button {
                    computeHourly()
                } label: {
                    Text("Compute")
                        .lineLimit(1)
                        .textCase(.none)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            if !hourlyRate.isEmpty {
                HStack {
                    Text("Hourly rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(hourlyRate)
                        .font(.title3)
                        .bold()
                }
            }
            if showValidation {
                Text("Enter a valid amount and select a duration greater than 0.")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .flexErrnCardStyle()
    }

    private var scheduleCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Block window")
                    .font(.headline)
                Spacer()
                Picker("", selection: $dateMode) {
                    Text("Today").tag(0)
                    Text("Future").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            if dateMode == 1 {
                DatePicker("Select date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .tint(datePickerControlColor)
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Start time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: Binding(get: { selectedStartTime }, set: startTimeChanged), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("End time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: Binding(get: { selectedEndTime }, set: endTimeChanged), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }
        }
        .flexErrnCardStyle()
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders")
                .font(.headline)
            Text(reminderDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Include 15-minute reminder", isOn: includePreReminderBinding)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity)
        .flexErrnCardStyle()
    }

    private var actionRow: some View {
        Button {
            acceptBlock()
        } label: {
            Text("Accept Block")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    private func sectionBlockList(title: String, blocks: [Block], showStartButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(blocks, id: \.id) { block in
                NavigationLink(destination: BlockDetailView(block: block)) {
                    BlockCard(block: block, showStartButton: showStartButton)
                }
                .buttonStyle(.plain)
            }
        }
        .flexErrnCardStyle()
    }

    @ViewBuilder
    private func BlockCard(block: Block, showStartButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.date, style: .date)
                    .font(.subheadline)
                Spacer()
                Text(block.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Complete") { complete(block) }
                        .disabled(block.status == .completed)
                    Button("Cancel") { cancel(block) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            Text("\(blockTimeFormatter.string(from: startDate(for: block))) – \(blockTimeFormatter.string(from: endDate(for: block)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gross: \(formatCurrency(block.grossPayout))")
                        .font(.caption2)
                    Text("Expenses: \(formatCurrency(block.additionalExpensesTotal))")
                        .font(.caption2)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Miles: \(formatDecimal(block.miles))")
                        .font(.caption2)
                    Text("Profit: \(formatCurrency(block.totalProfit))")
                        .font(.caption2)
                }
            }
            if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
                Text("Tracking: \(String(format: "%.2f", mileageTracker.currentMiles)) mi")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            } else {
                if showStartButton {
                    HStack {
                        Spacer()
                        Button("Start GPS tracking") {
                            mileageTracker.requestAuthorization()
                            mileageTracker.startTracking(for: block.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(!mileageTracker.canStartTracking)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private func startTimer() {
        currentTime = Date()
    }

    // existing helpers below (computeHourly, acceptBlock, etc.)
    private func pickerPill<T: Hashable, C: RandomAccessCollection>(title: String, value: Binding<T>, range: C) -> some View where C.Element == T, C.Element: Hashable {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Picker(title, selection: value) {
                ForEach(Array(range), id: \.self) { item in
                    Text("\(item)").tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .labelsHidden()
        }
        .frame(minWidth: 60)
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
        NotificationManager.shared.scheduleBlockReminders(for: block, includePreReminder: includePreReminderPreference)
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

    private func cancel(_ block: Block) {
        guard block.status != .cancelled else { return }
        block.status = .cancelled
        logStatusChange(for: block, note: "Marked cancelled from calculator")
        block.updatedAt = Date()
        context.saveIfNeeded()
    }

    private func complete(_ block: Block) {
        guard block.status != .completed else { return }
        block.status = .completed
        logStatusChange(for: block, note: "Marked completed from calculator")
        block.updatedAt = Date()
        context.saveIfNeeded()
    }

    private func logStatusChange(for block: Block, note: String) {
        let entry = AuditEntry(action: .statusChanged, note: note)
        block.auditEntries.append(entry)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let ns = value as NSDecimalNumber
        return ns.stringValue
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
                guard block.status == .accepted else { return false }
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

private extension ModelContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        try? save()
    }
}
