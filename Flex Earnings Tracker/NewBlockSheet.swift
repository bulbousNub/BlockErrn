import SwiftUI
import SwiftData

struct NewBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @State private var date = Date()
    @State private var grossBaseText: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var showValidation: Bool = false
    @State private var status: BlockStatus = .accepted
    @State private var notes: String = ""
    @State private var hasTips: Bool = false
    @State private var tipsText: String = ""
    @State private var milesText: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var expenses: [ExpenseRow] = []
    @State private var newExpenseCategoryID: String = ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
    @State private var newExpenseAmount: String = ""
    @State private var newExpenseNote: String = ""
    @FocusState private var focusedField: Field?

    init() {
        let baseDate = Calendar.current.startOfDay(for: Date())
        _startTime = State(initialValue: baseDate.addingTimeInterval(9 * 3600)) // 9 AM
        _endTime = State(initialValue: baseDate.addingTimeInterval(11 * 3600)) // 11 AM
        _hours = State(initialValue: 2)
        _minutes = State(initialValue: 0)
    }

    private enum Field {
        case gross
        case tips
        case miles
        case expenseAmount
        case expenseNote
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Start time", selection: Binding(get: { startTime }, set: startTimeChanged), displayedComponents: .hourAndMinute)
                    DatePicker("End time", selection: Binding(get: { endTime }, set: endTimeChanged), displayedComponents: .hourAndMinute)
                    HStack {
                        Picker("Hours", selection: Binding(get: { hours }, set: durationChangedHours)) {
                            ForEach(0..<9) { h in
                                Text("\(h) h").tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        Text(":")
                        Picker("Minutes", selection: Binding(get: { minutes }, set: durationChangedMinutes)) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d m", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Payout") {
                    TextField("Gross payout ($)", text: $grossBaseText)
                        .keyboardType(.decimalPad)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .gross)
                        .autocorrectionDisabled(true)
                    Toggle("Has tips", isOn: $hasTips)
                    if hasTips {
                        TextField("Tips ($)", text: $tipsText)
                            .keyboardType(.decimalPad)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .tips)
                            .autocorrectionDisabled(true)
                    }
                }

                Section("Status & Notes") {
                    Picker("Status", selection: $status) {
                        ForEach(BlockStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section("Mileage") {
                    TextField("Miles", text: $milesText)
                        .keyboardType(.decimalPad)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .miles)
                        .autocorrectionDisabled(true)
                    let rate = settings.first?.irsMileageRate ?? 0.70
                    HStack {
                        Text("IRS rate")
                        Spacer()
                        Text("$\(NSDecimalNumber(decimal: rate).stringValue)/mi")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Expenses") {
                    if expenses.isEmpty {
                        Text("No expenses added yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(expenses) { row in
                            VStack(alignment: .leading) {
                                Text(categoryName(for: row.categoryRaw))
                                Text("$\(row.amount) • \(row.note ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Picker("Category", selection: $newExpenseCategoryID) {
                        ForEach(categoryDescriptors) { descriptor in
                            Text(descriptor.name).tag(descriptor.id)
                        }
                    }
                    TextField("Amount ($)", text: $newExpenseAmount)
                        .keyboardType(.decimalPad)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .expenseAmount)
                        .autocorrectionDisabled(true)
                    TextField("Note", text: $newExpenseNote)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .expenseNote)
                        .autocorrectionDisabled(true)
                    Button("Add expense") {
                        addExpense()
                    }
                    .disabled(newExpenseAmount.isEmpty)
                }

                if showValidation {
                    Text("Enter all required fields and a duration greater than 0 minutes.")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("New Block")
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onChange(of: date) { newDate in
                startTime = combine(date: newDate, time: startTime)
                endTime = combine(date: newDate, time: endTime)
            }
            .onAppear {
                focusedField = .gross
                ensureValidNewExpenseCategorySelection()
            }
            .onChange(of: expenseCategoryIDs) { _ in
                ensureValidNewExpenseCategorySelection()
            }
        }
    }

    private func save() {
        guard let gross = Decimal(string: grossBaseText), gross >= 0 else {
            showValidation = true
            return
        }
        guard totalDurationMinutes > 0 else {
            showValidation = true
            return
        }

        let rate = settings.first?.irsMileageRate ?? 0.70
        let block = Block(
            date: date,
            durationMinutes: totalDurationMinutes,
            grossBase: gross,
            hasTips: hasTips,
            tipsAmount: hasTips ? Decimal(string: tipsText) ?? 0 : nil,
            miles: Decimal(string: milesText) ?? 0,
            irsRateSnapshot: rate,
            status: status
        )
        block.notes = notes
        block.startTime = startTime
        block.endTime = endTime
        for expenseRow in expenses {
            if let amount = Decimal(string: expenseRow.amount) {
                let expense = Expense(
                    categoryRaw: expenseRow.categoryRaw,
                    amount: amount,
                    note: expenseRow.note
                )
                block.expenses.append(expense)
            }
        }
        block.auditEntries.append(AuditEntry(action: AuditAction.created, note: "Block added manually"))
        context.insert(block)
        let includePreReminder = settings.first?.includePreReminder ?? true
        NotificationManager.shared.scheduleBlockReminders(for: block, includePreReminder: includePreReminder)
        try? context.save()
        dismiss()
    }

    private var totalDurationMinutes: Int {
        hours * 60 + minutes
    }

    private func startTimeChanged(_ newValue: Date) {
        startTime = combine(date: date, time: newValue)
        syncEndTimeWithDuration()
    }

    private func endTimeChanged(_ newValue: Date) {
        endTime = combine(date: date, time: newValue)
        alignDurationWithEnd()
    }

    private func durationChangedHours(_ newValue: Int) {
        hours = newValue
        syncEndTimeWithDuration()
    }

    private func durationChangedMinutes(_ newValue: Int) {
        minutes = newValue
        syncEndTimeWithDuration()
    }

    private func syncEndTimeWithDuration() {
        guard totalDurationMinutes > 0 else { return }
        endTime = startTime.addingTimeInterval(TimeInterval(totalDurationMinutes * 60))
    }

    private func alignDurationWithEnd() {
        let diff = max(1, Int(endTime.timeIntervalSince(startTime) / 60))
        hours = diff / 60
        minutes = diff % 60
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components) ?? date
    }

    private func addExpense() {
        let categoryRaw = expenseCategoryIDs.contains(newExpenseCategoryID) ? newExpenseCategoryID : defaultNewExpenseCategoryID
        let row = ExpenseRow(
            categoryRaw: categoryRaw,
            amount: newExpenseAmount,
            note: newExpenseNote.isEmpty ? nil : newExpenseNote
        )
        expenses.append(row)
        newExpenseAmount = ""
        newExpenseNote = ""
    }

    private var categoryDescriptors: [ExpenseCategoryDescriptor] {
        settings.first?.expenseCategoryDescriptors ?? ExpenseCategoryDescriptor.defaultList
    }

    private var expenseCategoryIDs: [String] {
        categoryDescriptors.map(\.id)
    }

    private var defaultNewExpenseCategoryID: String {
        categoryDescriptors.first?.id ?? ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
    }

    private func ensureValidNewExpenseCategorySelection() {
        if !expenseCategoryIDs.contains(newExpenseCategoryID) {
            newExpenseCategoryID = defaultNewExpenseCategoryID
        }
    }

    private func categoryName(for raw: String) -> String {
        categoryDescriptors.first(where: { $0.id == raw })?.name ?? raw.capitalized
    }
}

private struct ExpenseRow: Identifiable {
    let id = UUID()
    let categoryRaw: String
    let amount: String
    let note: String?
}
