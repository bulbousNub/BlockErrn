import SwiftUI
import SwiftData
import CoreLocation

struct BlockDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var mileageTracker: MileageTracker
    @State var block: Block

    @State private var showAddExpense = false
    @State private var showStartConfirmation = false
    @State private var showCompletionPrompt = false

    var body: some View {
        Form {
            Section("Overview") {
                DatePicker("Date", selection: Binding(get: { block.date }, set: { block.date = $0; touch() }), displayedComponents: .date)
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(block.durationMinutes/60)h \(block.durationMinutes%60)m")
                        .foregroundStyle(.secondary)
                }
                Picker("Status", selection: Binding(get: { block.status }, set: { block.status = $0; log(AuditAction.statusChanged) })) {
                    ForEach(BlockStatus.allCases) { s in Text(s.displayName).tag(s) }
                }
                TextField("Notes", text: Binding(get: { block.notes ?? "" }, set: { block.notes = $0; touch() }), axis: .vertical)
            }

            Section("Payout") {
                DecimalField("Base ($)", value: Binding(get: { block.grossBase }, set: { block.grossBase = $0; touch() }))
                Toggle("Has tips", isOn: Binding(get: { block.hasTips }, set: { block.hasTips = $0; touch() }))
                if block.hasTips {
                    OptionalDecimalField(title: "Tips ($)", value: Binding(get: { block.tipsAmount }, set: { block.tipsAmount = $0; touch(); log(AuditAction.tipsUpdated) }))
                    if block.tipsAmount == nil {
                        Text("Enter the tip amount once it posts (typically 24 hours after the block).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Gross payout")
                    Spacer()
                    Text(formatCurrency(block.grossPayout))
                }
            }

            Section("Schedule") {
                DatePicker("Start time", selection: Binding(get: { block.startTime ?? block.date }, set: { startTimeChanged(to: $0) }), displayedComponents: .hourAndMinute)
                DatePicker("End time", selection: Binding(get: { block.endTime ?? block.date }, set: { endTimeChanged(to: $0) }), displayedComponents: .hourAndMinute)
                Text("\(blockTimeFormatter.string(from: block.startTime ?? block.date)) – \(blockTimeFormatter.string(from: block.endTime ?? block.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Mileage") {
                DecimalField("Miles", value: Binding(get: { block.miles }, set: { block.miles = $0; touch(); log(AuditAction.milesUpdated) }))
                HStack {
                    Text("Rate snapshot")
                    Spacer()
                    Text(formatCurrency(block.irsRateSnapshot))
                    Text("/mi").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Mileage deduction")
                    Spacer()
                    Text(formatCurrency(block.mileageDeduction))
                }
                if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
                    Text("Tracking: \(String(format: "%.2f", mileageTracker.currentMiles)) mi")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                if mileageTracker.authorizationStatus == .denied {
                    Text("GPS permission is denied. Enable it in Settings to track mileage.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                Button {
                    showStartConfirmation = true
                } label: {
                        Label("Start tracking miles", systemImage: "location")
                    }
                    .disabled(mileageTracker.isTracking || !mileageTracker.canStartTracking)

                    Button {
                    if let roundedMiles = mileageTracker.stopTracking(for: block.id) {
                        block.miles = Decimal(roundedMiles)
                        touch()
                        promptCompletion()
                    }
                } label: {
                    Label("Stop tracking", systemImage: "location.slash")
                }
                    .disabled(!(mileageTracker.isTracking && mileageTracker.currentBlockID == block.id))
                }
            }

            Section("Expenses") {
                if block.expenses.isEmpty {
                    Text("No expenses yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(block.expenses, id: \.id) { e in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ExpenseCategory(rawValue: e.categoryRaw)?.displayName ?? e.categoryRaw.capitalized)
                                if let note = e.note, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(e.amount))
                            if ExpenseCategory(rawValue: e.categoryRaw)?.excludedFromTotals == true {
                                Text("Excluded").font(.caption2).padding(4).background(Color.gray.opacity(0.2)).cornerRadius(4)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                if let idx = block.expenses.firstIndex(where: { $0.id == e.id }) {
                                    let removed = block.expenses.remove(at: idx)
                                    log(AuditAction.expenseRemoved, field: "expense", oldValue: removed.categoryRaw, newValue: nil)
                                    touch()
                                }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                Button("Add Expense") { showAddExpense = true }
            }

            Section("Totals") {
                HStack { Text("Additional expenses"); Spacer(); Text(formatCurrency(block.additionalExpensesTotal)) }
                HStack { Text("Total profit"); Spacer(); Text(formatCurrency(block.totalProfit)) }
            }
        }
        .navigationTitle("Block Details")
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Mark Completed") { block.status = .completed; log(AuditAction.statusChanged) }
                    Button("Mark Cancelled") { block.status = .cancelled; log(AuditAction.statusChanged) }
                    Button("Mark No-Show") { block.status = .noShow; log(AuditAction.statusChanged) }
                } label: { Label("Status", systemImage: "checkmark.circle") }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(block: $block)
        }
        .onAppear {
            mileageTracker.requestAuthorization()
        }
        .alert("Start GPS tracking for this block?", isPresented: $showStartConfirmation) {
            Button("Start") {
                mileageTracker.startTracking(for: block.id)
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Block complete?", isPresented: $showCompletionPrompt) {
            Button("Mark Completed") {
                markBlockCompleted()
            }
            Button("Keep Status", role: .cancel) { }
        } message: {
            Text("Tracking stopped. Would you like to mark this block as completed?")
        }
    }

    private func touch() {
        block.updatedAt = Date()
        try? context.save()
    }

    private func promptCompletion() {
        if block.status != .completed {
            showCompletionPrompt = true
        }
    }

    private func markBlockCompleted() {
        guard block.status != .completed else { return }
        block.status = .completed
        log(AuditAction.statusChanged)
        touch()
    }

    private func log(_ action: AuditAction, field: String? = nil, oldValue: String? = nil, newValue: String? = nil) {
        let entry = AuditEntry(action: action, field: field, oldValue: oldValue, newValue: newValue)
        block.auditEntries.append(entry)
        try? context.save()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func startTimeChanged(to newStart: Date) {
        block.startTime = newStart
        let durationMinutes = max(1, block.durationMinutes)
        block.endTime = newStart.addingTimeInterval(TimeInterval(durationMinutes * 60))
        block.durationMinutes = durationMinutes
        touch()
    }

    private func endTimeChanged(to newEnd: Date) {
        block.endTime = newEnd
        let effectiveStart = block.startTime ?? block.date
        let intervalMinutes = Int(max(1, newEnd.timeIntervalSince(effectiveStart) / 60))
        block.durationMinutes = intervalMinutes
        touch()
    }
}

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var block: Block

    @State private var category: ExpenseCategory = .drinks
    @State private var amount: Decimal = 0
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                DecimalField("Amount ($)", value: $amount)
                TextField("Note", text: $note)
            }
            .navigationTitle("Add Expense")
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { add() } }
            }
        }
    }

    private func add() {
        let e = Expense(category: category, amount: amount, note: note)
        block.expenses.append(e)
        let entry = AuditEntry(action: AuditAction.expenseAdded, field: "expense", newValue: category.rawValue)
        block.auditEntries.append(entry)
        dismiss()
    }
}

struct DecimalField: View {
    let title: String
    @Binding var value: Decimal

    init(_ title: String, value: Binding<Decimal>) {
        self.title = title
        self._value = value
    }

    @State private var text: String = ""

    var body: some View {
        TextField(title, text: Binding(
            get: { text.isEmpty ? (value as NSDecimalNumber).stringValue : text },
            set: { newText in
                text = newText
                if let d = Decimal(string: newText) { value = d }
            }
        ))
        .keyboardType(.decimalPad)
        .onAppear { text = (value as NSDecimalNumber).stringValue }
        .onChange(of: value) { newValue in
            text = (newValue as NSDecimalNumber).stringValue
        }
    }
}

struct OptionalDecimalField: View {
    let title: String
    @Binding var value: Decimal?
    @State private var text: String = ""

    var body: some View {
        TextField(title, text: Binding(
            get: {
                if text.isEmpty {
                    if let v = value {
                        return (v as NSDecimalNumber).stringValue
                    } else {
                        return ""
                    }
                } else {
                    return text
                }
            },
            set: { newText in
                text = newText
                if newText.isEmpty {
                    value = nil
                } else if let d = Decimal(string: newText) {
                    value = d
                }
            }
        ))
        .keyboardType(.decimalPad)
        .onAppear {
            if let v = value {
                text = (v as NSDecimalNumber).stringValue
            } else {
                text = ""
            }
        }
        .onChange(of: value) { newValue in
            if let nv = newValue {
                text = (nv as NSDecimalNumber).stringValue
            } else {
                text = ""
            }
        }
    }
}
