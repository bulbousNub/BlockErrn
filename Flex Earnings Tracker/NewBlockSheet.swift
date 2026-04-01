import SwiftUI
import SwiftData

struct NewBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @State private var date = Date()
    @State private var grossBase: Decimal = 0
    @State private var showValidation: Bool = false
    @State private var status: BlockStatus = .accepted
    @State private var notes: String = ""
    @State private var hasTips: Bool = false
    @State private var tipAmount: Decimal? = nil
    @State private var milesValue: Decimal = 0
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var expenses: [ExpenseRow] = []
    @State private var showAddExpenseSheet: Bool = false
    @FocusState private var focusedField: Field?

    init() {
        let baseDate = Calendar.current.startOfDay(for: Date())
        _startTime = State(initialValue: baseDate.addingTimeInterval(9 * 3600)) // 9 AM
        _endTime = State(initialValue: baseDate.addingTimeInterval(11 * 3600)) // 11 AM
    }

    private enum Field {
        case gross
        case tips
        case miles
        case expenseAmount
        case expenseNote
        case notes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        overviewCard
                        payoutCard
                        scheduleCard
                        mileageCard
                        expensesCard
                        if showValidation {
                            Text("Enter all required fields and a duration greater than 0 minutes.")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 32)
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
            }
        }
        .sheet(isPresented: $showAddExpenseSheet) {
            ManualExpenseSheet(
                expenses: $expenses,
                categoryDescriptors: categoryDescriptors,
                defaultCategoryID: defaultNewExpenseCategoryID
            )
        }
    }

    private func save() {
        guard grossBase >= 0 else {
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
            grossBase: grossBase,
            hasTips: hasTips,
            tipsAmount: hasTips ? (tipAmount ?? 0) : nil,
            miles: milesValue,
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
        logBlockCreationFields(for: block, note: "Captured via manual entry", currencyFormatter: currencyString)
        context.insert(block)
        NotificationManager.shared.scheduleBlockReminders(for: block, config: defaultReminderConfiguration)
        try? context.save()
        dismiss()
    }

    private var defaultReminderConfiguration: NotificationManager.ReminderConfiguration {
        let setting = settings.first
        return NotificationManager.ReminderConfiguration(
            startMinutes: setting?.reminderBeforeStartMinutes ?? 45,
            preEndMinutes: setting?.reminderBeforeEndMinutes ?? 15,
            tipHours: setting?.tipReminderHours ?? 24,
            startEnabled: true,
            preEndEnabled: true,
            endEnabled: true,
            tipEnabled: hasTips,
            hasTips: hasTips
        )
    }

    private var totalDurationMinutes: Int {
        let minutes = Int(max(1, endTime.timeIntervalSince(startTime) / 60))
        return minutes
    }

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
        startTime = combine(date: date, time: newValue)
        if endTime <= startTime {
            endTime = startTime.addingTimeInterval(60)
        }
    }

    private func endTimeChanged(_ newValue: Date) {
        endTime = combine(date: date, time: newValue)
        if endTime <= startTime {
            startTime = endTime.addingTimeInterval(-60)
        }
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

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
            HStack {
                Text("Status")
                Spacer()
                Picker("", selection: $status) {
                    ForEach(BlockStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.black)
            }
            LiquidNotesField(placeholder: "Notes", text: $notes)
                .focused($focusedField, equals: .notes)
            }
        .flexErrnCardStyle()
    }

    private var payoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payout")
                .font(.headline)
            DecimalField("Gross payout", prefix: "$", value: $grossBase)
                .focused($focusedField, equals: .gross)
            Toggle("Has tips", isOn: Binding(
                get: { hasTips },
                set: { newValue in
                    hasTips = newValue
                    if !newValue {
                        tipAmount = nil
                    }
                }
            ))
            if hasTips {
                OptionalDecimalField(
                    title: "Tips",
                    prefix: "$",
                    value: Binding(
                        get: { tipAmount },
                        set: { tipAmount = $0 }
                    )
                )
                .focused($focusedField, equals: .tips)
            }
            HStack {
                Text("Gross payout")
                Spacer()
                Text(currencyString(for: grossTotal))
                    .foregroundStyle(.secondary)
            }
        }
        .flexErrnCardStyle()
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.headline)
            DatePicker("Start time", selection: Binding(get: { startTime }, set: startTimeChanged), displayedComponents: .hourAndMinute)
            DatePicker("End time", selection: Binding(get: { endTime }, set: endTimeChanged), displayedComponents: .hourAndMinute)
            HStack {
                Text("Duration")
                Spacer()
                Text(durationText(for: totalDurationMinutes))
                    .foregroundStyle(.secondary)
            }
        }
        .flexErrnCardStyle()
    }

    private var mileageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mileage")
                .font(.headline)
            MilesField(
                "Miles",
                value: $milesValue,
                displayValue: roundedMilesDecimal(milesValue)
            )
            .focused($focusedField, equals: .miles)
            HStack {
                Text("IRS rate")
                Spacer()
                Text("$\(NSDecimalNumber(decimal: settings.first?.irsMileageRate ?? 0.70).stringValue)/mi")
                    .foregroundStyle(.secondary)
            }
        }
        .flexErrnCardStyle()
    }

    private var expensesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses")
                    .font(.headline)
                Spacer()
                Button {
                    showAddExpenseSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .buttonBorderShape(.circle)
                .tint(.black)
            }
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
        }
        .flexErrnCardStyle()
    }

    private var grossTotal: Decimal {
        grossBase + (tipAmount ?? 0)
    }

    private func roundedMilesDecimal(_ miles: Decimal) -> Decimal {
        var mutable = miles
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutable, 0, .plain)
        return rounded
    }

    private func currencyString(for value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private var categoryDescriptors: [ExpenseCategoryDescriptor] {
        settings.first?.expenseCategoryDescriptors ?? ExpenseCategoryDescriptor.defaultList
    }

    private var defaultNewExpenseCategoryID: String {
        categoryDescriptors.first?.id ?? ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
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

private struct ManualExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var expenses: [ExpenseRow]
    let categoryDescriptors: [ExpenseCategoryDescriptor]

    @State private var selectedCategoryID: String
    @State private var amount: Decimal = 0
    @State private var note: String = ""

    init(expenses: Binding<[ExpenseRow]>, categoryDescriptors: [ExpenseCategoryDescriptor], defaultCategoryID: String) {
        self._expenses = expenses
        self.categoryDescriptors = categoryDescriptors
        self._selectedCategoryID = State(initialValue: defaultCategoryID)
    }

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    compactInputs
                    noteCard
                    actionRow
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
        .onAppear { ensureValidSelection() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add an expense")
                .font(.title3)
                .bold()
            Text("Capture expenses related to your trip before they slip your mind.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldTint: Color {
        colorScheme == .light ? .primary : .accentColor
    }

    private var compactInputs: some View {
        HStack(spacing: 12) {
            categoryCard
            amountCard
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("Category", selection: $selectedCategoryID) {
                ForEach(categoryDescriptors) { descriptor in
                    Text(descriptor.name).tag(descriptor.id)
                }
            }
            .pickerStyle(.menu)
            .tint(fieldTint)
        }
        .flexErrnCardStyle()
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.footnote)
                .foregroundStyle(.secondary)
            DecimalField("Amount", prefix: "$", value: $amount)
        }
        .flexErrnCardStyle()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LiquidNotesField(placeholder: "Optional note", text: $note)
        }
        .flexErrnCardStyle()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Add") {
                add()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .disabled(amount == 0)
    }

    private func add() {
        let row = ExpenseRow(
            categoryRaw: categoryDescriptors.first(where: { $0.id == selectedCategoryID })?.id ?? defaultCategoryID,
            amount: (amount as NSDecimalNumber).stringValue,
            note: note.isEmpty ? nil : note
        )
        expenses.append(row)
        dismiss()
    }

    private var categoryIDs: [String] {
        categoryDescriptors.map(\.id)
    }

    private var defaultCategoryID: String {
        categoryDescriptors.first?.id ?? ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
    }

    private func ensureValidSelection() {
        if !categoryIDs.contains(selectedCategoryID) {
            selectedCategoryID = defaultCategoryID
        }
    }
}
