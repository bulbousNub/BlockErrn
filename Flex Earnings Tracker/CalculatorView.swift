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

    @EnvironmentObject private var mileageTracker: MileageTracker

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroCard
                        earningsCard
                        scheduleCard
                        remindersCard
                        actionRow

                        if !activeBlocks.isEmpty {
                            sectionBlockList(title: "Active blocks", blocks: activeBlocks)
                        }

                        if !upcomingBlocks.isEmpty {
                            sectionBlockList(title: "Upcoming blocks", blocks: upcomingBlocks)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Calculator")
            .onAppear { startTimer() }
            .alert("Block accepted", isPresented: $showAcceptedAlert) {
                Button("Great") { }
            } message: {
                Text("FlexErrn saved your block and scheduled reminders.")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan with confidence")
                .font(.headline)
            Text("Use the blocks below or create a new entry—the tracker handles gross, tips, mileage, and reminders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading) {
                    Text("Next reminder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Date(), format: .dateTime.hour().minute())")
                        .font(.title2)
                        .bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Current rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(settings.first?.irsMileageRate.formatted(.currency(code: "USD")) ?? "$0.70/mi")
                        .font(.title3)
                        .bold()
                }
            }
        }
        .flexErrnCardStyle()
    }

    private var earningsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Gross payout")
                    .font(.headline)
                Spacer()
            }
            TextField("Gross payout ($)", text: $grossBaseText)
                .keyboardType(.decimalPad)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.leading)
                .keyboardDoneToolbar()

            Divider()

            HStack(spacing: 12) {
                pickerPill(title: "Hours", value: $selectedHours, range: 0..<9)
                pickerPill(title: "Minutes", value: $selectedMinutes, range: [0, 15, 30, 45])
                Spacer()
                Button("Compute") {
                    computeHourly()
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
            Text("FlexErrn will ping you 15 minutes before your scheduled end and again when the block is due.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Include 15-minute reminder", isOn: .constant(true))
                .labelsHidden()
                .disabled(true)
                .foregroundStyle(.secondary)
        }
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

    private func sectionBlockList(title: String, blocks: [Block]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(blocks, id: \.id) { block in
                NavigationLink(destination: BlockDetailView(block: block)) {
                    BlockCard(block: block)
                }
                .buttonStyle(.plain)
            }
        }
        .flexErrnCardStyle()
    }

    @ViewBuilder
    private func BlockCard(block: Block) -> some View {
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
                Text("Miles: \(formatDecimal(block.miles))")
                Spacer()
                Text("Profit: \(formatCurrency(block.totalProfit))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
                Text("Tracking: \(String(format: "%.2f", mileageTracker.currentMiles)) mi")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            } else {
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
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private func startTimer() {
        currentTime = Date()
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

