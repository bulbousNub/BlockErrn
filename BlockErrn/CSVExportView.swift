import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVExportView: View {
    private enum ExportField: String, CaseIterable, Identifiable {
        case blockID
        case date
        case durationMinutes
        case status
        case notes
        case basePay
        case hasTips
        case tipsAmount
        case grossPayout
        case grossPerHour
        case scheduledStart
        case scheduledEnd
        case userStartTime
        case userCompletionTime
        case roundedMiles
        case rateSnapshot
        case mileageDeduction
        case expensesTotal
        case totalProfit
        case profitPerHour
        case expenses
        case auditEntries

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .blockID: return "Block ID"
            case .date: return "Date"
            case .durationMinutes: return "Duration"
            case .status: return "Status"
            case .notes: return "Notes"
            case .basePay: return "Base Pay"
            case .hasTips: return "Has Tips"
            case .tipsAmount: return "Tips Amount"
            case .grossPayout: return "Gross Payout"
            case .grossPerHour: return "Gross $/hr"
            case .scheduledStart: return "Scheduled Start"
            case .scheduledEnd: return "Scheduled End"
            case .userStartTime: return "User Start Time"
            case .userCompletionTime: return "User Completion Time"
            case .roundedMiles: return "Whole Miles"
            case .rateSnapshot: return "Rate Snapshot"
            case .mileageDeduction: return "Mileage Deduction"
            case .expensesTotal: return "Expenses Total"
            case .totalProfit: return "Total Profit"
            case .profitPerHour: return "Total Profit $/hr"
            case .expenses: return "Expenses"
            case .auditEntries: return "Audit Entries"
            }
        }
    }

    private static let exportFieldOrder: [ExportField] = [
        .blockID, .date, .durationMinutes, .status, .notes,
        .basePay, .hasTips, .tipsAmount, .grossPayout, .grossPerHour,
        .scheduledStart, .scheduledEnd, .userStartTime, .userCompletionTime,
        .roundedMiles, .rateSnapshot, .mileageDeduction, .expensesTotal,
        .totalProfit, .profitPerHour, .expenses, .auditEntries
    ]

    @Query private var blocks: [Block]
    @ObservedObject private var store = StoreKitManager.shared
    @State private var selectedFields: Set<ExportField> = Set(exportFieldOrder)
    @State private var showCSVExporter: Bool = false
    @State private var showProUpgrade: Bool = false
    @State private var csvDocument: CSVDocument = .empty
    @State private var exportMessage: String?
    @State private var exportMessageStyle: DataMessageStyle = .info

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    fieldSelectionCard
                    generateCard
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Export to CSV")
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: defaultCSVFilename()
        ) { result in
            switch result {
            case .success(let url):
                exportMessage = "CSV ready: \(url.lastPathComponent)"
                exportMessageStyle = .success
            case .failure(let error):
                exportMessage = "CSV failed: \(error.localizedDescription)"
                exportMessageStyle = .error
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CSV Export")
                        .font(.title2)
                        .bold()
                    Text("Share your data with other tools or spreadsheets by exporting every block, expense, and audit entry to a CSV you can open anywhere.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(blocks.count) blocks will be exported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Field Selection

    private var fieldSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Columns")
                    .font(.headline)
                Spacer()
                if store.isProUnlocked {
                    Button(selectedFields.count == Self.exportFieldOrder.count ? "Deselect All" : "Select All") {
                        if selectedFields.count == Self.exportFieldOrder.count {
                            selectedFields.removeAll()
                        } else {
                            selectedFields = Set(Self.exportFieldOrder)
                        }
                    }
                    .font(.caption)
                }
            }

            if store.isProUnlocked {
                Text("Choose which columns to include in the exported CSV file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Self.exportFieldOrder) { field in
                        Toggle(isOn: Binding(
                            get: { selectedFields.contains(field) },
                            set: { isSelected in
                                if isSelected {
                                    selectedFields.insert(field)
                                } else {
                                    selectedFields.remove(field)
                                }
                            }
                        )) {
                            Text(field.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                    }
                }
            } else {
                Text("Free export includes all columns. Upgrade to Pro to customize which columns are included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ProLockedBanner(feature: "CSV Column Configuration") {
                    showProUpgrade = true
                }
                .sheet(isPresented: $showProUpgrade) {
                    NavigationStack {
                        ProUpgradeView()
                    }
                }
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Generate

    private var generateCard: some View {
        VStack(spacing: 12) {
            Button {
                exportData()
            } label: {
                Label("Export to CSV", systemImage: "square.and.arrow.up.on.square")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(blocks.isEmpty || selectedFields.isEmpty)

            if let message = exportMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(exportMessageStyle.color)
                    .multilineTextAlignment(.center)
            }

            if blocks.isEmpty {
                Text("No blocks to export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if selectedFields.isEmpty {
                Text("Select at least one column to export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - CSV Generation

    private func exportData() {
        exportMessage = nil
        csvDocument = CSVDocument(text: makeCSVText())
        showCSVExporter = true
    }

    private func defaultCSVFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "BlockErrnData-\(formatter.string(from: Date())).csv"
    }

    private func makeCSVText() -> String {
        let fields = Self.exportFieldOrder.filter { selectedFields.contains($0) }
        guard !fields.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let headerRow = fields.map { csvEscaped($0.displayName) }.joined(separator: ",")

        let rows = blocks.map { block -> String in
            let scheduledStart = block.startTime ?? block.date
            let scheduledEnd = block.endTime ?? scheduledStart.addingTimeInterval(TimeInterval(max(1, block.durationMinutes) * 60))
            let grossPayout = block.grossPayout
            let durationHours = Decimal(max(1, block.durationMinutes)) / 60
            let grossPerHour = durationHours > 0 ? grossPayout / durationHours : grossPayout
            let totalProfit = block.totalProfit
            let profitPerHour = durationHours > 0 ? totalProfit / durationHours : totalProfit
            let expensesTotal = block.additionalExpensesTotal
            let mileageDeduction = block.mileageDeduction
            let roundedMiles = block.roundedMiles

            let ctx = RowContext(
                block: block,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                grossPayout: grossPayout,
                grossPerHour: grossPerHour,
                totalProfit: totalProfit,
                profitPerHour: profitPerHour,
                expensesTotal: expensesTotal,
                mileageDeduction: mileageDeduction,
                roundedMiles: roundedMiles
            )

            let values = fields.map { fieldValue(for: $0, ctx: ctx, formatter: formatter) }
            return values.map(csvEscaped).joined(separator: ",")
        }

        return ([headerRow] + rows).joined(separator: "\n")
    }

    private struct RowContext {
        let block: Block
        let scheduledStart: Date
        let scheduledEnd: Date
        let grossPayout: Decimal
        let grossPerHour: Decimal
        let totalProfit: Decimal
        let profitPerHour: Decimal
        let expensesTotal: Decimal
        let mileageDeduction: Decimal
        let roundedMiles: Decimal
    }

    private func fieldValue(for field: ExportField, ctx: RowContext, formatter: DateFormatter) -> String {
        switch field {
        case .blockID:
            return ctx.block.id.uuidString
        case .date:
            return isoString(for: ctx.block.date, formatter: formatter)
        case .durationMinutes:
            return "\(ctx.block.durationMinutes)"
        case .status:
            return ctx.block.statusRaw
        case .notes:
            return ctx.block.notes ?? ""
        case .basePay:
            return decimalString(ctx.block.grossBase)
        case .hasTips:
            return ctx.block.hasTips ? "true" : "false"
        case .tipsAmount:
            return decimalString(ctx.block.tipsAmount ?? 0)
        case .grossPayout:
            return decimalString(ctx.grossPayout)
        case .grossPerHour:
            return decimalString(ctx.grossPerHour)
        case .scheduledStart:
            return isoString(for: ctx.scheduledStart, formatter: formatter)
        case .scheduledEnd:
            return isoString(for: ctx.scheduledEnd, formatter: formatter)
        case .userStartTime:
            return isoString(for: ctx.block.userStartTime, formatter: formatter)
        case .userCompletionTime:
            return isoString(for: ctx.block.userCompletionTime, formatter: formatter)
        case .roundedMiles:
            return decimalString(ctx.roundedMiles)
        case .rateSnapshot:
            return decimalString(ctx.block.irsRateSnapshot)
        case .mileageDeduction:
            return decimalString(ctx.mileageDeduction)
        case .expensesTotal:
            return decimalString(ctx.expensesTotal)
        case .totalProfit:
            return decimalString(ctx.totalProfit)
        case .profitPerHour:
            return decimalString(ctx.profitPerHour)
        case .expenses:
            return jsonString(ctx.block.expenses.map { ExpenseCSVRow(categoryRaw: $0.categoryRaw, amount: $0.amount, note: $0.note, createdAt: $0.createdAt) })
        case .auditEntries:
            return jsonString(ctx.block.auditEntries.map { AuditCSVRow(timestamp: $0.timestamp, actionRaw: $0.actionRaw, field: $0.field, oldValue: $0.oldValue, newValue: $0.newValue, note: $0.note) })
        }
    }

    // MARK: - Helpers

    private func isoString(for date: Date?, formatter: DateFormatter) -> String {
        guard let date = date else { return "" }
        return formatter.string(from: date)
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func jsonString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

// MARK: - Supporting Types

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                configuration.label
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents,
              let string = String(data: contents, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }

    static var empty: CSVDocument {
        CSVDocument(text: "")
    }
}

private struct ExpenseCSVRow: Encodable {
    let categoryRaw: String
    let amount: Decimal
    let note: String?
    let createdAt: Date
}

private struct AuditCSVRow: Encodable {
    let timestamp: Date
    let actionRaw: String
    let field: String?
    let oldValue: String?
    let newValue: String?
    let note: String?
}
