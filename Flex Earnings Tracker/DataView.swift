import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct DataView: View {
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
        .blockID,
        .date,
        .durationMinutes,
        .status,
        .notes,
        .basePay,
        .hasTips,
        .tipsAmount,
        .grossPayout,
        .grossPerHour,
        .scheduledStart,
        .scheduledEnd,
        .userStartTime,
        .userCompletionTime,
        .roundedMiles,
        .rateSnapshot,
        .mileageDeduction,
        .expensesTotal,
        .totalProfit,
        .profitPerHour,
        .expenses,
        .auditEntries
    ]
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query private var blocks: [Block]

    @State private var shareableBackup: ShareableBackup?
    @State private var showCSVExporter: Bool = false
    @State private var csvDocument: CSVDocument = .empty
    @State private var selectedExportFields: Set<ExportField> = Set(Self.exportFieldOrder)
    @State private var showImporter: Bool = false
    @State private var backupMessage: String?
    @State private var backupMessageStyle: DataMessageStyle = .info
    @State private var importMessage: String?
    @State private var importMessageStyle: DataMessageStyle = .info
    @State private var exportMessage: String?
    @State private var exportMessageStyle: DataMessageStyle = .info
    @State private var lastBackupDate: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    dataCard
                    exportTile
                    backupTile
                    importTile
                }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Data")
            .sheet(item: $shareableBackup) { backup in
                ActivityView(activityItems: [backup.url])
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .fileExporter(
                isPresented: $showCSVExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: defaultCSVFilename()
            ) { result in
                switch result {
                case .success(let url):
                    setExportMessage("CSV ready: \(url.lastPathComponent)", style: .success)
                case .failure(let error):
                    setExportMessage("CSV failed: \(error.localizedDescription)", style: .error)
                }
            }
            .onAppear {
                loadLastBackupDate()
            }
        }
    }

    private var backupTile: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Backup")
                        .font(.title3)
                        .bold()
                    Text("Create a full FlexErrn snapshot to safeguard every block, expense, note, and route. Backing up regularly keeps your history protected even if you reinstall or move devices.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(backupTimestampText)
                        .font(.headline)
                        .foregroundColor(backupStatusColor)
                }
            }

            Button {
                backupData()
            } label: {
                Label("Backup FlexErrn Data", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            if let message = backupMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(backupMessageStyle.color)
                    .multilineTextAlignment(.center)
            }
            }
            .flexErrnCardStyle()
    }

    private var importTile: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Import")
                        .font(.title3)
                        .bold()
                    Text("Restore a previously exported FlexErrn backup whenever you switch phones, reinstall, or need to recover your blocks and settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            Button {
                showImporter = true
            } label: {
                Label("Import FlexErrn Backup", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)

            if let message = importMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(importMessageStyle.color)
                    .multilineTextAlignment(.center)
            }
        }
        .flexErrnCardStyle()
    }

    private var exportTile: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export to CSV")
                        .font(.title3)
                        .bold()
                    Text("Share your data with other tools or spreadsheets by exporting every block, expense, and audit entry to a CSV you can open anywhere. Use the checkboxes below to control which columns are included before tapping Export.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            exportFieldSelection

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

            if let message = exportMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(exportMessageStyle.color)
                    .multilineTextAlignment(.center)
            }
        }
        .flexErrnCardStyle()
    }

    private var exportFieldSelection: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Self.exportFieldOrder) { field in
            Toggle(isOn: Binding(
                get: { selectedExportFields.contains(field) },
                set: { isSelected in
                    if isSelected {
                        selectedExportFields.insert(field)
                    } else {
                        selectedExportFields.remove(field)
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
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Data Management")
                        .font(.title2)
                        .bold()
                    Text("Manage backups, imports, exports, and destructive resets for your FlexErrn history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text("Use these controls to share data, restore previous backups, or erase everything when needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        }
        .flexErrnCardStyle()
    }

    private func backupData() {
        do {
            let url = try createBackupFile()
            shareableBackup = ShareableBackup(url: url)
            let now = Date()
            recordBackupDate(now)
            backupMessage = "Backup ready"
            backupMessageStyle = .success
        } catch {
            backupMessage = "Backup failed: \(error.localizedDescription)"
            backupMessageStyle = .error
        }
    }

    private func loadLastBackupDate() {
        if let stored = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date {
            lastBackupDate = stored
        } else {
            lastBackupDate = nil
        }
    }

    private func recordBackupDate(_ date: Date) {
        lastBackupDate = date
        UserDefaults.standard.set(date, forKey: Self.lastBackupKey)
    }

    private var backupTimestampText: String {
        guard let date = lastBackupDate else { return "No backups yet" }
        return Self.backupDateFormatter.string(from: date)
    }

    private var backupStatusColor: Color {
        guard let date = lastBackupDate else { return .red }
        let age = Date().timeIntervalSince(date)
        let day = TimeInterval(24 * 60 * 60)
        if age <= 6 * day {
            return .green
        }
        if age <= 13 * day {
            return Color.yellow
        }
        return .red
    }

    private static let lastBackupKey = "FlexErrnLastBackupDate"
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStop {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(BackupPayload.self, from: data)
                try importBackup(payload)
                setImportMessage("Imported backup from \(url.lastPathComponent)", style: .success)
            } catch {
                setImportMessage("Import failed: \(error.localizedDescription)", style: .error)
            }
        case .failure(let error):
            setImportMessage("Import cancelled: \(error.localizedDescription)", style: .info)
        }
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "FlexEarningsBackup-\(formatter.string(from: Date())).json"
    }

    private func defaultCSVFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "FlexErrnData-\(formatter.string(from: Date())).csv"
    }

    private func makeCSVText() -> String {
        let selectedFields = Self.exportFieldOrder.filter { selectedExportFields.contains($0) }
        guard !selectedFields.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let headerRow = selectedFields.map { csvEscaped($0.displayName) }.joined(separator: ",")

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
            let context = BlockCSVContext(
                block: block,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                durationHours: durationHours,
                grossPayout: grossPayout,
                grossPerHour: grossPerHour,
                totalProfit: totalProfit,
                profitPerHour: profitPerHour,
                expensesTotal: expensesTotal,
                mileageDeduction: mileageDeduction,
                roundedMiles: roundedMiles
            )

            let values = selectedFields.map { fieldValue(for: $0, context: context, formatter: formatter) }
            return values.map(csvEscaped).joined(separator: ",")
        }

        let combined = ([headerRow] + rows).joined(separator: "\n")
        return combined
    }

    private func fieldValue(for field: ExportField, context: BlockCSVContext, formatter: DateFormatter) -> String {
        switch field {
        case .blockID:
            return context.block.id.uuidString
        case .date:
            return isoString(for: context.block.date, formatter: formatter)
        case .durationMinutes:
            return "\(context.block.durationMinutes)"
        case .status:
            return context.block.statusRaw
        case .notes:
            return context.block.notes ?? ""
        case .basePay:
            return decimalString(context.block.grossBase)
        case .hasTips:
            return context.block.hasTips ? "true" : "false"
        case .tipsAmount:
            return decimalString(context.block.tipsAmount ?? 0)
        case .grossPayout:
            return decimalString(context.grossPayout)
        case .grossPerHour:
            return decimalString(context.grossPerHour)
        case .scheduledStart:
            return isoString(for: context.scheduledStart, formatter: formatter)
        case .scheduledEnd:
            return isoString(for: context.scheduledEnd, formatter: formatter)
        case .userStartTime:
            return isoString(for: context.block.userStartTime, formatter: formatter)
        case .userCompletionTime:
            return isoString(for: context.block.userCompletionTime, formatter: formatter)
        case .roundedMiles:
            return decimalString(context.roundedMiles)
        case .rateSnapshot:
            return decimalString(context.block.irsRateSnapshot)
        case .mileageDeduction:
            return decimalString(context.mileageDeduction)
        case .expensesTotal:
            return decimalString(context.expensesTotal)
        case .totalProfit:
            return decimalString(context.totalProfit)
        case .profitPerHour:
            return decimalString(context.profitPerHour)
        case .expenses:
            return jsonString(context.block.expenses.map { ExpenseCSV(categoryRaw: $0.categoryRaw, amount: $0.amount, note: $0.note, createdAt: $0.createdAt) })
        case .auditEntries:
            return jsonString(context.block.auditEntries.map { AuditCSV(timestamp: $0.timestamp, actionRaw: $0.actionRaw, field: $0.field, oldValue: $0.oldValue, newValue: $0.newValue, note: $0.note) })
        }
    }

    private struct BlockCSVContext {
        let block: Block
        let scheduledStart: Date
        let scheduledEnd: Date
        let durationHours: Decimal
        let grossPayout: Decimal
        let grossPerHour: Decimal
        let totalProfit: Decimal
        let profitPerHour: Decimal
        let expensesTotal: Decimal
        let mileageDeduction: Decimal
        let roundedMiles: Decimal
    }

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

    private func setExportMessage(_ text: String, style: DataMessageStyle) {
        exportMessage = text
        exportMessageStyle = style
    }

    private func exportData() {
        exportMessage = nil
        csvDocument = CSVDocument(text: makeCSVText())
        showCSVExporter = true
    }

    private func setImportMessage(_ text: String, style: DataMessageStyle) {
        importMessage = text
        importMessageStyle = style
    }

    private func makeBackupPayload() -> BackupPayload {
        let blockPayloads = blocks.map { block in
            BlockPayload(
                id: block.id,
                date: block.date,
                durationMinutes: block.durationMinutes,
                grossBase: block.grossBase,
                hasTips: block.hasTips,
                tipsAmount: block.tipsAmount,
                miles: block.miles,
                irsRateSnapshot: block.irsRateSnapshot,
                statusRaw: block.statusRaw,
                notes: block.notes,
                createdAt: block.createdAt,
                updatedAt: block.updatedAt,
                expenses: block.expenses.map { expense in
                    ExpensePayload(
                        id: expense.id,
                        categoryRaw: expense.categoryRaw,
                        amount: expense.amount,
                        note: expense.note,
                        createdAt: expense.createdAt
                    )
                },
                auditEntries: block.auditEntries.map { audit in
                    AuditEntryPayload(
                        id: audit.id,
                        timestamp: audit.timestamp,
                        action: audit.actionRaw,
                        field: audit.field,
                        oldValue: audit.oldValue,
                        newValue: audit.newValue,
                        note: audit.note
                    )
                },
                startTime: block.startTime,
                endTime: block.endTime,
                routePoints: block.routePoints,
                userStartTime: block.userStartTime,
                userCompletionTime: block.userCompletionTime
            )
        }

        let settingsPayloads = settings.map { setting in
            AppSettingsPayload(
                id: setting.id,
                irsMileageRate: setting.irsMileageRate,
                currencyCode: setting.currencyCode,
                roundingScale: setting.roundingScale,
                preferredAppearanceRaw: setting.preferredAppearanceRaw,
                includePreReminder: setting.includePreReminder,
                expenseCategoryDescriptors: setting.expenseCategoryDescriptors
            )
        }

        return BackupPayload(blocks: blockPayloads, settings: settingsPayloads)
    }

    private func createBackupFile() throws -> URL {
        let payload = makeBackupPayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(defaultBackupFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    private func importBackup(_ payload: BackupPayload) throws {
        for blockPayload in payload.blocks {
            let block = Block(
                id: blockPayload.id,
                date: blockPayload.date,
                durationMinutes: blockPayload.durationMinutes,
                grossBase: blockPayload.grossBase,
                hasTips: blockPayload.hasTips,
                tipsAmount: blockPayload.tipsAmount,
                miles: blockPayload.miles,
                irsRateSnapshot: blockPayload.irsRateSnapshot,
                status: BlockStatus(rawValue: blockPayload.statusRaw) ?? .accepted,
                expenses: [],
                auditEntries: [],
                notes: blockPayload.notes,
                createdAt: blockPayload.createdAt,
                updatedAt: blockPayload.updatedAt
            )

            block.startTime = blockPayload.startTime
            block.endTime = blockPayload.endTime
            block.routePoints = blockPayload.routePoints

            block.userStartTime = blockPayload.userStartTime
            block.userCompletionTime = blockPayload.userCompletionTime

            for expensePayload in blockPayload.expenses {
                let category = ExpenseCategory(rawValue: expensePayload.categoryRaw) ?? .drinks
                let expense = Expense(
                    id: expensePayload.id,
                    category: category,
                    amount: expensePayload.amount,
                    note: expensePayload.note,
                    createdAt: expensePayload.createdAt
                )
                block.expenses.append(expense)
            }

            for auditPayload in blockPayload.auditEntries {
                let action = AuditAction(rawValue: auditPayload.action) ?? .updated
                let entry = AuditEntry(
                    id: auditPayload.id,
                    timestamp: auditPayload.timestamp,
                    action: action,
                    field: auditPayload.field,
                    oldValue: auditPayload.oldValue,
                    newValue: auditPayload.newValue,
                    note: auditPayload.note
                )
                block.auditEntries.append(entry)
            }

            context.insert(block)
        }

        for setting in settings {
            context.delete(setting)
        }

        for settingPayload in payload.settings {
            let setting = AppSettings(
                id: settingPayload.id,
                irsMileageRate: settingPayload.irsMileageRate,
                currencyCode: settingPayload.currencyCode,
                roundingScale: settingPayload.roundingScale,
                includePreReminder: settingPayload.includePreReminder ?? true,
                expenseCategories: settingPayload.expenseCategoryDescriptors
            )
            setting.preferredAppearanceRaw = settingPayload.preferredAppearanceRaw
            context.insert(setting)
        }

        try context.save()
    }
}

private struct ShareableBackup: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum DataMessageStyle {
    case info
    case success
    case error

    var color: Color {
        switch self {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

private struct BackupPayload: Codable {
    let blocks: [BlockPayload]
    let settings: [AppSettingsPayload]
}

private struct BlockPayload: Codable {
    let id: UUID
    let date: Date
    let durationMinutes: Int
    let grossBase: Decimal
    let hasTips: Bool
    let tipsAmount: Decimal?
    let miles: Decimal
    let irsRateSnapshot: Decimal
    let statusRaw: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let expenses: [ExpensePayload]
    let auditEntries: [AuditEntryPayload]
    let startTime: Date?
    let endTime: Date?
    let routePoints: [RoutePoint]?
    let userStartTime: Date?
    let userCompletionTime: Date?
}

private struct ExpensePayload: Codable {
    let id: UUID
    let categoryRaw: String
    let amount: Decimal
    let note: String?
    let createdAt: Date
}

private struct AuditEntryPayload: Codable {
    let id: UUID
    let timestamp: Date
    let action: String
    let field: String?
    let oldValue: String?
    let newValue: String?
    let note: String?
}

private struct AppSettingsPayload: Codable {
    let id: UUID
    let irsMileageRate: Decimal
    let currencyCode: String
    let roundingScale: Int
    let preferredAppearanceRaw: String?
    let includePreReminder: Bool?
    let expenseCategoryDescriptors: [ExpenseCategoryDescriptor]?
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

private struct ExpenseCSV: Encodable {
    let categoryRaw: String
    let amount: Decimal
    let note: String?
    let createdAt: Date
}

private struct AuditCSV: Encodable {
    let timestamp: Date
    let actionRaw: String
    let field: String?
    let oldValue: String?
    let newValue: String?
    let note: String?
}

#Preview {
    DataView()
        .modelContainer(for: [Block.self, Expense.self, AuditEntry.self, AppSettings.self], inMemory: true)
}
