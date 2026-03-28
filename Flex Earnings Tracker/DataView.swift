import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct DataView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query private var blocks: [Block]

    @State private var shareableBackup: ShareableBackup?
    @State private var showCSVExporter: Bool = false
    @State private var csvDocument: CSVDocument = .empty
    @State private var showImporter: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var dataMessage: String?
    @State private var dataMessageStyle: DataMessageStyle = .info

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        dataCard
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
                    setDataMessage("CSV ready: \(url.lastPathComponent)", style: .success)
                case .failure(let error):
                    setDataMessage("CSV failed: \(error.localizedDescription)", style: .error)
                }
            }
            .alert("Delete all saved data?", isPresented: $showClearConfirmation) {
                Button("Delete Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes every block, expense, and custom setting. The action cannot be undone.")
            }
        }
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Data management")
                        .font(.title2)
                        .bold()
                    Text("This tab handles backup and import functions to protect your FlexErrn data and also exports every record for safekeeping.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text("Backups, restores, and exports all live right here so you can share or recover your data whenever needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                do {
                    let url = try createBackupFile()
                    shareableBackup = ShareableBackup(url: url)
                    setDataMessage("Backup ready", style: .success)
                } catch {
                    setDataMessage("Backup failed: \(error.localizedDescription)", style: .error)
                }
            } label: {
                Label("Backup FlexErrn Data", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)

            Button {
                showImporter = true
            } label: {
                Label("Import FlexErrn Backup", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)

            Button {
                csvDocument = CSVDocument(text: makeCSVText())
                showCSVExporter = true
            } label: {
                Label("Export to CSV", systemImage: "square.and.arrow.up.on.square")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)

            if let message = dataMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(dataMessageStyle.color)
                    .multilineTextAlignment(.center)
            }

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.red)
        }
        .flexErrnCardStyle()
    }

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
                setDataMessage("Imported backup from \(url.lastPathComponent)", style: .success)
            } catch {
                setDataMessage("Import failed: \(error.localizedDescription)", style: .error)
            }
        case .failure(let error):
            setDataMessage("Import cancelled: \(error.localizedDescription)", style: .info)
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
        let header = [
            "Block ID", "Date", "Start Time", "End Time", "Duration Minutes",
            "Gross Base", "Has Tips", "Tips Amount", "Miles", "IRS Rate Snapshot",
            "Status", "Notes", "Created At", "Updated At", "Expenses", "Audit Entries"
        ]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let rows = blocks.map { block -> String in
            let values: [String] = [
                block.id.uuidString,
                isoString(for: block.date, formatter: formatter),
                isoString(for: block.startTime ?? block.date, formatter: formatter),
                isoString(for: block.endTime ?? block.date.addingTimeInterval(TimeInterval(max(1, block.durationMinutes) * 60)), formatter: formatter),
                "\(block.durationMinutes)",
                decimalString(block.grossBase),
                block.hasTips ? "true" : "false",
                decimalString(block.tipsAmount ?? 0),
                decimalString(block.miles),
                decimalString(block.irsRateSnapshot),
                block.statusRaw,
                block.notes ?? "",
                isoString(for: block.createdAt, formatter: formatter),
                isoString(for: block.updatedAt, formatter: formatter),
                jsonString(block.expenses.map { ExpenseCSV(categoryRaw: $0.categoryRaw, amount: $0.amount, note: $0.note, createdAt: $0.createdAt) }),
                jsonString(block.auditEntries.map { AuditCSV(timestamp: $0.timestamp, actionRaw: $0.actionRaw, field: $0.field, oldValue: $0.oldValue, newValue: $0.newValue, note: $0.note) })
            ]
            return values.map(csvEscaped).joined(separator: ",")
        }

        let combined = ([header.map(csvEscaped).joined(separator: ",")] + rows).joined(separator: "\n")
        return combined
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

    private func setDataMessage(_ text: String, style: DataMessageStyle) {
        dataMessage = text
        dataMessageStyle = style
    }

    private func clearAllData() {
        for block in blocks {
            context.delete(block)
        }
        for setting in settings {
            context.delete(setting)
        }
        try? context.save()
        setDataMessage("All data removed. Blocks and settings cleared.", style: .info)
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

private enum DataMessageStyle {
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
