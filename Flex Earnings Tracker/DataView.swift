import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct DataView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query private var blocks: [Block]
    @ObservedObject private var iCloudManager = ICloudBackupManager.shared

    @State private var shareableBackup: ShareableBackup?
    @State private var showImporter: Bool = false
    @State private var backupMessage: String?
    @State private var backupMessageStyle: DataMessageStyle = .info
    @State private var importMessage: String?
    @State private var importMessageStyle: DataMessageStyle = .info
    @State private var lastBackupDate: Date?
    @State private var useZipBackup: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                BlockErrnTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        dataCard
                        csvTile
                        reportTile
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
                allowedContentTypes: [.json, .zip],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .onAppear {
                loadLastBackupDate()
                loadBackupFormatPreference()
            }
        }
    }

    // MARK: - Data Card

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Data Management")
                        .font(.title2)
                        .bold()
                    Text("Generate reports, export your data, and manage backups for your BlockErrn history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text("Create branded PDF reports, export to CSV for spreadsheets, back up your data, or restore from a previous backup.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .flexErrnCardStyle()
    }

    // MARK: - Report Tile

    private var reportTile: some View {
        NavigationLink {
            ReportView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Earnings Report")
                            .font(.title3)
                            .bold()
                        Text("Generate a branded PDF report with earnings summaries, block logs, expense breakdowns, and efficiency metrics. Filter by date and status, then preview and share.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                }
                HStack {
                    Text("Generate Report")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                )
            }
            .flexErrnCardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - CSV Tile

    private var csvTile: some View {
        NavigationLink {
            CSVExportView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Export to CSV")
                            .font(.title3)
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
                    Text("Export CSV")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                )
            }
            .flexErrnCardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Backup Tile

    private var backupTile: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Backup")
                        .font(.title3)
                        .bold()
                    Text("Create a full BlockErrn snapshot to safeguard every block, expense, note, and route. Backing up regularly keeps your history protected even if you reinstall or move devices.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last backup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        backupRow(label: "Local", date: lastBackupDate)
                        backupRow(label: "iCloud", date: iCloudManager.lastBackupDate)
                    }
                    Spacer()
                    backupFormatToggle
                }
            }
            Button {
                backupData()
            } label: {
                Label("Backup BlockErrn Data", systemImage: "square.and.arrow.up")
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
            Text("JSON includes the payload plus inline receipt data; ZIP bundles the same JSON plus separate JPEG files.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                ICloudBackupView()
            } label: {
                HStack {
                    Image(systemName: "icloud")
                    Text("iCloud Backup")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .flexErrnCardStyle()
    }

    private var backupFormatToggle: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("JSON")
                .font(.subheadline)
                .foregroundStyle(useZipBackup ? .secondary : .primary)
            Toggle("", isOn: $useZipBackup)
                .labelsHidden()
                .tint(.accentColor)
            Text("Zip")
                .font(.subheadline)
                .foregroundStyle(useZipBackup ? .primary : .secondary)
        }
        .onChange(of: useZipBackup) { storeBackupFormatPreference($0) }
    }

    // MARK: - Import Tile

    private var importTile: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Import")
                        .font(.title3)
                        .bold()
                    Text("Restore a previously exported BlockErrn backup whenever you switch phones, reinstall, or need to recover your blocks and settings.")
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
                Label("Import BlockErrn Backup", systemImage: "square.and.arrow.down")
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

    // MARK: - Backup Logic

    private func backupData() {
        do {
            let url = try createBackupFile(useZip: useZipBackup)
            shareableBackup = ShareableBackup(url: url)
            let now = Date()
            recordBackupDate(now)
            backupMessage = "Backup ready"
            backupMessageStyle = .success
            triggerICloudBackup()
        } catch {
            backupMessage = "Backup failed: \(error.localizedDescription)"
            backupMessageStyle = .error
        }
    }

    private func triggerICloudBackup() {
        guard iCloudManager.isEnabled else { return }
        let payload = makeBackupPayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        iCloudManager.uploadBackup(jsonData: data)
    }

    private func loadLastBackupDate() {
        if let stored = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date {
            lastBackupDate = stored
        } else {
            lastBackupDate = nil
        }
    }

    private func storeBackupFormatPreference(_ useZip: Bool) {
        UserDefaults.standard.set(useZip, forKey: Self.backupFormatKey)
    }

    private func loadBackupFormatPreference() {
        if UserDefaults.standard.object(forKey: Self.backupFormatKey) != nil {
            useZipBackup = UserDefaults.standard.bool(forKey: Self.backupFormatKey)
        }
    }

    private func recordBackupDate(_ date: Date) {
        lastBackupDate = date
        UserDefaults.standard.set(date, forKey: Self.lastBackupKey)
    }

    private func backupRow(label: String, date: Date?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: label == "iCloud" ? "icloud.fill" : "internaldrive.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let date {
                Text(Self.backupDateFormatter.string(from: date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Self.colorForBackupAge(date))
            } else {
                Text("Never")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
    }

    private static func colorForBackupAge(_ date: Date) -> Color {
        let age = Date().timeIntervalSince(date)
        let day = TimeInterval(24 * 60 * 60)
        if age <= 6 * day { return .green }
        if age <= 13 * day { return .yellow }
        return .red
    }

    private static let lastBackupKey = "BlockErrnLastBackupDate"
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Import Logic

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
                let data = try readBackupData(from: url)
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

    private func setImportMessage(_ text: String, style: DataMessageStyle) {
        importMessage = text
        importMessageStyle = style
    }

    private func readBackupData(from url: URL) throws -> Data {
        if url.pathExtension.lowercased() == "zip" {
            guard let archive = Archive(url: url, accessMode: .read),
                  let entry = archive[Self.backupJSONFilename] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            return data
        }
        return try Data(contentsOf: url)
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "FlexEarningsBackup-\(formatter.string(from: Date())).zip"
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
                        createdAt: expense.createdAt,
                        updatedAt: expense.updatedAt,
                        receiptFileName: expense.receiptFileName,
                        receiptData: ReceiptStorage.loadData(named: expense.receiptFileName)
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
                hasDismissedPlanCard: setting.hasDismissedPlanCard,
                hasCompletedOnboarding: setting.hasCompletedOnboarding,
                reminderBeforeStartMinutes: setting.reminderBeforeStartMinutes,
                reminderBeforeEndMinutes: setting.reminderBeforeEndMinutes,
                tipReminderHours: setting.tipReminderHours,
                expenseCategoryDescriptors: setting.expenseCategoryDescriptors
            )
        }

        return BackupPayload(blocks: blockPayloads, settings: settingsPayloads)
    }

    private func createBackupFile(useZip: Bool) throws -> URL {
        let payload = makeBackupPayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent(Self.backupJSONFilename)
        try data.write(to: jsonURL, options: .atomic)
        guard useZip else { return jsonURL }
        let zipURL = tempDir.appendingPathComponent(defaultBackupFilename())
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try archive.addEntry(with: Self.backupJSONFilename, relativeTo: tempDir)
        try addReceiptFiles(to: archive, payload: payload, tempDir: tempDir)
        try FileManager.default.removeItem(at: jsonURL)
        return zipURL
    }

    private func addReceiptFiles(to archive: Archive, payload: BackupPayload, tempDir: URL) throws {
        let fileManager = FileManager.default
        let receiptFileNames = payload.blocks
            .flatMap { $0.expenses }
            .compactMap { $0.receiptFileName }
        let uniqueReceipts = Set(receiptFileNames)
        guard !uniqueReceipts.isEmpty else { return }
        let receiptsTempDir = tempDir.appendingPathComponent(Self.backupReceiptsFolder, isDirectory: true)
        if fileManager.fileExists(atPath: receiptsTempDir.path) {
            try fileManager.removeItem(at: receiptsTempDir)
        }
        try fileManager.createDirectory(at: receiptsTempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: receiptsTempDir)
        }

        let storedReceiptsDir = try ReceiptStorage.receiptsDirectory()
        for fileName in uniqueReceipts.sorted() {
            let sourceURL = storedReceiptsDir.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
            let destinationURL = receiptsTempDir.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try archive.addEntry(with: "\(Self.backupReceiptsFolder)/\(fileName)", relativeTo: tempDir)
        }
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
                    createdAt: expensePayload.createdAt,
                    updatedAt: expensePayload.updatedAt
                )
                if let data = expensePayload.receiptData {
                    let savedFile = ReceiptStorage.save(data: data, fileName: expensePayload.receiptFileName)
                    expense.receiptFileName = savedFile
                }
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
                hasDismissedPlanCard: settingPayload.hasDismissedPlanCard ?? false,
                expenseCategories: settingPayload.expenseCategoryDescriptors,
                hasCompletedOnboarding: settingPayload.hasCompletedOnboarding ?? false,
                reminderBeforeStartMinutes: settingPayload.reminderBeforeStartMinutes ?? 45,
                reminderBeforeEndMinutes: settingPayload.reminderBeforeEndMinutes ?? 15,
                tipReminderHours: settingPayload.tipReminderHours ?? 24
            )
            setting.preferredAppearanceRaw = settingPayload.preferredAppearanceRaw
            context.insert(setting)
        }

        try context.save()
    }

    private static let backupJSONFilename = "BlockErrnBackup.json"
    private static let backupFormatKey = "BlockErrnBackupFormatUseZip"
    private static let backupReceiptsFolder = "Receipts"
}

// MARK: - Supporting Types

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
    let updatedAt: Date?
    let receiptFileName: String?
    let receiptData: Data?
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
    let hasDismissedPlanCard: Bool?
    let hasCompletedOnboarding: Bool?
    let reminderBeforeStartMinutes: Int?
    let reminderBeforeEndMinutes: Int?
    let tipReminderHours: Int?
    let expenseCategoryDescriptors: [ExpenseCategoryDescriptor]?
}

#Preview {
    DataView()
        .modelContainer(for: [Block.self, Expense.self, AuditEntry.self, AppSettings.self], inMemory: true)
}
