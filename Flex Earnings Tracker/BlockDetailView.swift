import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct BlockDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var mileageTracker: MileageTracker
    @State var block: Block

    @Query private var settings: [AppSettings]

    @State private var showAddExpense = false
    @State private var showStartConfirmation = false
    @State private var showCompletionPrompt = false
    @Environment(\.colorScheme) private var colorScheme

    private var showLegacyTrackingControls: Bool { false }

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    overviewCard
                    payoutCard
                    scheduleCard
                    routeCard
                    mileageCard
                    expensesCard
                    totalsCard
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Block Details")
        .keyboardDoneToolbar()
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

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            DatePicker("Date", selection: Binding(get: { block.date }, set: { block.date = $0; touch() }), displayedComponents: .date)
                .datePickerStyle(.compact)
            HStack {
                Text("Duration")
                Spacer()
                Text("\(block.durationMinutes/60)h \(block.durationMinutes%60)m")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Block status")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Picker("Status", selection: Binding(get: { block.status }, set: { block.status = $0; log(AuditAction.statusChanged) })) {
                    ForEach(BlockStatus.allCases) { s in Text(s.displayName).tag(s) }
                }
                .pickerStyle(.menu)
                .tint(buttonTextColor)
            }
            LiquidNotesField(placeholder: "Notes", text: Binding(get: { block.notes ?? "" }, set: { block.notes = $0; touch() }))
            timestampRow
        }
        .flexErrnCardStyle()
    }

    private var timestampRow: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                Text("Created at \(Self.blockTimestampFormatter.string(from: block.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Text("Last Modified at \(Self.blockTimestampFormatter.string(from: block.updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var payoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payout")
                .font(.headline)
            DecimalField("Base Pay", prefix: "$", value: Binding(get: { block.grossBase }, set: { block.grossBase = $0; touch() }))
            Toggle("Has tips", isOn: Binding(get: { block.hasTips }, set: { block.hasTips = $0; touch() }))
            if block.hasTips {
                    OptionalDecimalField(title: "Tips", prefix: "$", value: Binding(get: { block.tipsAmount }, set: { block.tipsAmount = $0; touch(); log(AuditAction.tipsUpdated) }))
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
            HStack {
                Text("Gross $/hr")
                Spacer()
                Text(formatCurrency(grossPerHour()))
            }
        }
        .flexErrnCardStyle()
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.headline)
            DatePicker("Start time", selection: Binding(get: { block.startTime ?? block.date }, set: { startTimeChanged(to: $0) }), displayedComponents: .hourAndMinute)
            DatePicker("End time", selection: Binding(get: { block.endTime ?? block.date }, set: { endTimeChanged(to: $0) }), displayedComponents: .hourAndMinute)
            scheduleRow("User Start Time", block.userStartTime)
            scheduleRow("User Completion Time", block.userCompletionTime)
        }
        .flexErrnCardStyle()
    }

    private func scheduleRow(_ title: String, _ date: Date?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(date.map { Self.scheduleTimeFormatter.string(from: $0) } ?? "Not recorded")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    private static let scheduleTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    @ViewBuilder
    private var routeCard: some View {
            if let segments = block.routeSegments, !segments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route")
                        .font(.headline)
                    RouteMapView(routeSegments: segments)
                        .frame(height: 200)
                }
                .flexErrnCardStyle()
            }
    }

    private var mileageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mileage")
                .font(.headline)
            MilesField("Miles", value: Binding(get: { block.miles }, set: { block.miles = $0; touch(); log(AuditAction.milesUpdated) }), displayValue: block.roundedMiles)
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
            Toggle(isOn: Binding(
                get: { block.shouldExcludeMileageDeduction },
                set: { newValue in
                    let oldValue = block.shouldExcludeMileageDeduction
                    DeductionPreferenceStore.shared.setExclude(newValue, type: .mileage, blockID: block.id)
                    log(AuditAction.milesUpdated, field: "excludeMileageDeduction", oldValue: oldValue ? "true" : "false", newValue: newValue ? "true" : "false")
                    touch()
                }
            )) {
                Text("Exclude Mileage Deduction from Profit Calculation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
                Text("Tracking: \(String(format: "%.2f", mileageTracker.currentMiles)) mi")
                    .font(.caption2)
                    .foregroundColor(buttonTextColor)
            }
            if mileageTracker.authorizationStatus == .denied {
                Text("GPS permission is denied. Enable it in Settings to track mileage.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showLegacyTrackingControls {
                HStack(spacing: 12) {
                    Button {
                        showStartConfirmation = true
                    } label: {
                        Label("Start tracking miles", systemImage: "location")
                            .foregroundColor(startButtonColor)
                    }
                    .tint(startButtonTint)
                    .disabled(mileageTracker.isTracking || !mileageTracker.canStartTracking)

                    Button {
                        if let (sessionMiles, routePoints) = mileageTracker.stopTracking(for: block.id) {
                            block.miles += Decimal(sessionMiles)
                            block.appendRouteSegment(routePoints)
                            touch()
                            promptCompletion()
                        }
                    } label: {
                        Label("Stop tracking", systemImage: "location.slash")
                            .foregroundColor(buttonTextColor)
                    }
                    .tint(buttonTextColor)
                    .disabled(!(mileageTracker.isTracking && mileageTracker.currentBlockID == block.id))
                }
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
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(buttonTextColor)
                .buttonBorderShape(.circle)
            }
            if block.expenses.isEmpty {
                Text("No expenses yet")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach($block.expenses, id: \.id) { $expense in
                        NavigationLink {
                            ExpenseDetailView(expense: $expense, categoryDescriptors: categoryDescriptors)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(categoryName(for: expense.categoryRaw))
                                        .font(.headline)
                                    if let note = expense.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(formatCurrency(expense.amount))
                                        .font(.headline)
                                    if ExpenseCategory(rawValue: expense.categoryRaw)?.excludedFromTotals == true {
                                        Text("Excluded")
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    Text("Created at \(BlockDetailView.expenseTimestampFormatter.string(from: expense.createdAt))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let updated = expense.updatedAt, updated > expense.createdAt {
                                        Text("Updated at \(BlockDetailView.expenseTimestampFormatter.string(from: updated))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if DeductionPreferenceStore.shared.isExpenseExcluded(expense.id) {
                                        Text("Excluded from profit")
                                            .font(.caption2)
                                            .italic()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(colorScheme == .light ? .black : .secondary)
                            }
                            .contentShape(Rectangle())
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                if let idx = block.expenses.firstIndex(where: { $0.id == expense.id }) {
                                    let removed = block.expenses.remove(at: idx)
                                    log(AuditAction.expenseRemoved, field: "expense", oldValue: removed.categoryRaw, newValue: nil)
                                    touch()
                                }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            Toggle(isOn: Binding(
                get: { block.shouldExcludeExpensesDeduction },
                set: { newValue in
                    let oldValue = block.shouldExcludeExpensesDeduction
                    DeductionPreferenceStore.shared.setExclude(newValue, type: .expenses, blockID: block.id)
                    log(AuditAction.expenseAdded, field: "excludeExpenseDeduction", oldValue: oldValue ? "true" : "false", newValue: newValue ? "true" : "false")
                    touch()
                }
            )) {
                Text("Exclude All Expenses from Profit Calculation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity)
        .flexErrnCardStyle()
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Totals")
                .font(.headline)
            totalsRow(
                title: "Additional Expenses",
                subtitle: additionalExpensesSubtitle,
                value: block.additionalExpensesTotal,
                active: block.shouldIncludeExpensesDeduction
            )
            totalsRow(title: "Mileage deduction", subtitle: nil, value: block.mileageDeduction, active: block.shouldIncludeMileageDeduction)
            totalsRow(title: "Total profit", subtitle: nil, value: block.totalProfit, active: true)
            HStack { Text("Total Profit $/hr"); Spacer(); Text(formatCurrency(profitPerHour())) }
        }
        .flexErrnCardStyle()
    }

    private func totalsRow(title: String, subtitle: Text?, value: Decimal, active: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                styledLabel(Text(title), active: active)
                if let subtitle = subtitle {
                    subtitle
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            styledLabel(Text(formatCurrency(value)), active: active)
        }
    }

    private func styledLabel(_ text: Text, active: Bool) -> Text {
        var styled = text
            .foregroundStyle(active ? .primary : .secondary)
        if !active {
            styled = styled
                .strikethrough(true, color: .secondary)
                .italic()
        }
        return styled
    }

    private var additionalExpensesSubtitle: Text? {
        guard block.hasIndividuallyExcludedExpenses else { return nil }
        return Text("Individual Expenses Excluded")
            .italic()
            .foregroundStyle(.secondary)
    }

    private var buttonTextColor: Color {
        colorScheme == .light ? .primary : .accentColor
    }

    private var categoryDescriptors: [ExpenseCategoryDescriptor] {
        settings.first?.expenseCategoryDescriptors ?? ExpenseCategoryDescriptor.defaultList
    }

    private static let blockTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter
    }()

    private func categoryName(for raw: String) -> String {
        categoryDescriptors.first(where: { $0.id == raw })?.name ?? raw.capitalized
    }

    fileprivate static let expenseTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter
    }()

    private var isTrackingActive: Bool {
        mileageTracker.isTracking && mileageTracker.currentBlockID == block.id
    }

    private var startButtonColor: Color {
        if isTrackingActive {
            return Color.gray
        } else {
            return buttonTextColor
        }
    }

    private var startButtonTint: Color {
        isTrackingActive ? Color.gray.opacity(0.4) : buttonTextColor
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

    private func grossPerHour() -> Decimal {
        let minutes = max(1, block.durationMinutes)
        let hours = Decimal(minutes) / 60
        guard hours > 0 else { return block.grossPayout }
        return block.grossPayout / hours
    }

    private func profitPerHour() -> Decimal {
        let minutes = max(1, block.durationMinutes)
        let hours = Decimal(minutes) / 60
        guard hours > 0 else { return block.totalProfit }
        return block.totalProfit / hours
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

    @State private var selectedCategoryID: String = ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
    @State private var amount: Decimal = 0
    @State private var note: String = ""
    @Query private var settings: [AppSettings]
    @Environment(\.colorScheme) private var colorScheme

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
        .onChange(of: categoryIDs) { _ in ensureValidSelection() }
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
                ForEach(categories) { descriptor in
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
    }

    private func add() {
        let categoryRaw = categoryIDs.contains(selectedCategoryID) ? selectedCategoryID : defaultCategoryID
        let e = Expense(categoryRaw: categoryRaw, amount: amount, note: note)
        block.expenses.append(e)
        let entry = AuditEntry(action: AuditAction.expenseAdded, field: "expense", newValue: categoryRaw)
        block.auditEntries.append(entry)
        dismiss()
    }

    private var categories: [ExpenseCategoryDescriptor] {
        settings.first?.expenseCategoryDescriptors ?? ExpenseCategoryDescriptor.defaultList
    }

    private var categoryIDs: [String] {
        categories.map(\.id)
    }

    private var defaultCategoryID: String {
        categories.first?.id ?? ExpenseCategoryDescriptor.defaultList.first?.id ?? ExpenseCategory.drinks.rawValue
    }

    private func ensureValidSelection() {
        if !categoryIDs.contains(selectedCategoryID) {
            selectedCategoryID = defaultCategoryID
        }
    }

}

struct DecimalField: View {
    let title: String
    let prefix: String?
    @Binding var value: Decimal

    init(_ title: String, prefix: String? = nil, value: Binding<Decimal>) {
        self.title = title
        self.prefix = prefix
        self._value = value
    }

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 6) {
            if let prefix {
                Text(prefix)
                    .foregroundStyle(.secondary)
            }
            TextField(title, text: Binding(
                get: {
                    if text.isEmpty {
                        if value == 0 {
                            return ""
                        } else {
                            return (value as NSDecimalNumber).stringValue
                        }
                    } else {
                        return text
                    }
                },
                set: { newText in
                    text = newText
                    if let d = Decimal(string: newText) { value = d }
                }
            ))
            .keyboardType(.decimalPad)
            .onAppear {
                if value != 0 {
                    text = (value as NSDecimalNumber).stringValue
                } else {
                    text = ""
                }
            }
            .onChange(of: value) { newValue in
                if text.isEmpty {
                    if newValue != 0 {
                        text = (newValue as NSDecimalNumber).stringValue
                    }
                }
            }
        }
    }
}

struct MilesField: View {
    let title: String
    @Binding var value: Decimal
    let displayValue: Decimal
    @State private var text: String = ""

    init(_ title: String, value: Binding<Decimal>, displayValue: Decimal) {
        self.title = title
        self._value = value
        self.displayValue = displayValue
    }

    var body: some View {
        TextField(title, text: Binding(
            get: {
                if text.isEmpty {
                    if displayValue > 0 {
                        return (displayValue as NSDecimalNumber).stringValue
                    } else {
                        return ""
                    }
                } else {
                    return text
                }
            },
            set: { newText in
                text = newText
                if let d = Decimal(string: newText) {
                    value = d
                }
            }
        ))
        .keyboardType(.decimalPad)
        .onChange(of: displayValue) { newValue in
            if text.isEmpty && newValue > 0 {
                text = (newValue as NSDecimalNumber).stringValue
            }
        }
    }
}

struct OptionalDecimalField: View {
    let title: String
    let prefix: String?
    @Binding var value: Decimal?
    @State private var text: String = ""

    init(title: String, prefix: String? = nil, value: Binding<Decimal?>) {
        self.title = title
        self.prefix = prefix
        self._value = value
    }

    var body: some View {
        HStack(spacing: 6) {
            if let prefix {
                Text(prefix)
                    .foregroundStyle(.secondary)
            }
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
}

struct LiquidNotesField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }
}

private struct ExpenseDetailView: View {
    @Binding var expense: Expense
    let categoryDescriptors: [ExpenseCategoryDescriptor]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                detailCard
            }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Expense Detail")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var detailCard: some View {
        VStack(spacing: 16) {
            heroFields
            exclusionToggle
            noteField
            timestampRow
        }
        .padding()
        .flexErrnCardStyle()
    }

    private var heroFields: some View {
        HStack(spacing: 12) {
            heroBlock(title: "Category") {
                Menu {
                    ForEach(categoryDescriptors) { descriptor in
                        Button(descriptor.name) {
                            categoryBinding.wrappedValue = descriptor.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategoryName)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.accentColor)
            }

            heroBlock(title: "Amount") {
                DecimalField("Amount", prefix: "$", value: amountBinding)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var exclusionToggle: some View {
        heroBlock(title: "Profit impact") {
            Toggle("Exclude from profit", isOn: exclusionBinding)
                .toggleStyle(.switch)
                .tint(.accentColor)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("Add a note", text: noteBinding)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var timestampRow: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Created at \(BlockDetailView.expenseTimestampFormatter.string(from: expense.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let updated = expense.updatedAt, updated > expense.createdAt {
                    Text("Last Modified at \(BlockDetailView.expenseTimestampFormatter.string(from: updated))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func heroBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var selectedCategoryName: String {
        categoryDescriptors.first(where: { $0.id == expense.categoryRaw })?.name ?? expense.categoryRaw.capitalized
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { expense.categoryRaw },
            set: { newValue in
                expense.categoryRaw = newValue
                save()
            }
        )
    }

    private var amountBinding: Binding<Decimal> {
        Binding(
            get: { expense.amount },
            set: { newValue in
                expense.amount = newValue
                save()
            }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { expense.note ?? "" },
            set: { newValue in
                expense.note = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var exclusionBinding: Binding<Bool> {
        Binding(
            get: { DeductionPreferenceStore.shared.isExpenseExcluded(expense.id) },
            set: { newValue in
                DeductionPreferenceStore.shared.setExpenseExcluded(newValue, expenseID: expense.id)
                save()
            }
        )
    }

    private func save() {
        expense.updatedAt = Date()
        try? context.save()
    }

}

    private struct RouteMapView: UIViewRepresentable {
        let routeSegments: [[RoutePoint]]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.layer.cornerRadius = 16
        return mapView
    }

        func updateUIView(_ mapView: MKMapView, context: Context) {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)

            let segments = routeSegments.map { $0.map(\.coordinate) }.filter { !$0.isEmpty }
            guard !segments.isEmpty else {
                let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
                mapView.region = MKCoordinateRegion(center: defaultCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                return
            }

            let allCoords = segments.flatMap { $0 }
            let region = regionForCoordinates(allCoords)
            mapView.setRegion(region, animated: false)

            for segment in segments {
                if segment.count > 1 {
                    let polyline = MKPolyline(coordinates: segment, count: segment.count)
                    mapView.addOverlay(polyline)
                }
            }

            for (index, segment) in segments.enumerated() {
                if let start = segment.first {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = start
                    annotation.title = title(for: index, total: segments.count, type: .start)
                    mapView.addAnnotation(annotation)
                }
                if let end = segment.last, regionContains(region, coordinate: end) {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = end
                    annotation.title = title(for: index, total: segments.count, type: .end)
                    mapView.addAnnotation(annotation)
                }
            }
        }

    private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coords.map(\.latitude)
        let longitudes = coords.map(\.longitude)
        let maxLat = latitudes.max() ?? 0
        let minLat = latitudes.min() ?? 0
        let maxLong = longitudes.max() ?? 0
        let minLong = longitudes.min() ?? 0
        let center = CLLocationCoordinate2D(latitude: (maxLat + minLat) / 2, longitude: (maxLong + minLong) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.005, (maxLat - minLat) * 1.5), longitudeDelta: max(0.005, (maxLong - minLong) * 1.5))
        return MKCoordinateRegion(center: center, span: span)
    }

        private func regionContains(_ region: MKCoordinateRegion, coordinate: CLLocationCoordinate2D) -> Bool {
            let latInRange = coordinate.latitude >= region.center.latitude - region.span.latitudeDelta/2 &&
                coordinate.latitude <= region.center.latitude + region.span.latitudeDelta/2
            let lonInRange = coordinate.longitude >= region.center.longitude - region.span.longitudeDelta/2 &&
                coordinate.longitude <= region.center.longitude + region.span.longitudeDelta/2
            return latInRange && lonInRange
        }

        private enum AnnotationType { case start, end }

        private func title(for index: Int, total: Int, type: AnnotationType) -> String {
            if total == 1 {
                return type == .start ? "Start" : "End"
            }
            let label = type == .start ? "Start" : "End"
            return "\(label) - \(index + 1)"
        }

    fileprivate class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
