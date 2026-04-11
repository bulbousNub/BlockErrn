import SwiftUI
import SwiftData

struct ICloudBackupView: View {
    @ObservedObject private var iCloudManager = ICloudBackupManager.shared
    @Environment(\.modelContext) private var context
    @Query private var blocks: [Block]
    @Query private var settings: [AppSettings]

    @State private var showRestoreConfirmation = false
    @State private var restoreMessage: String?
    @State private var restoreMessageStyle: DataMessageStyle = .info
    @State private var remoteBackupExists = false
    @State private var remoteBackupDate: Date?
    @State private var backupMessage: String?
    @State private var backupMessageStyle: DataMessageStyle = .info

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    disclaimerCard
                    toggleCard
                    statusCard
                    if iCloudManager.isEnabled {
                        backupNowCard
                    }
                    restoreCard
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("iCloud Backup")
        .onAppear {
            iCloudManager.checkAvailability()
            checkForRemoteBackup()
        }
        .onChange(of: iCloudManager.isUploading) {
            // When upload finishes, show success or error
            if !iCloudManager.isUploading && backupMessage == "Backup started" {
                if let error = iCloudManager.lastError {
                    backupMessage = "Backup failed: \(error)"
                    backupMessageStyle = .error
                } else if iCloudManager.lastBackupDate != nil {
                    backupMessage = "Backup complete!"
                    backupMessageStyle = .success
                    checkForRemoteBackup()
                }
            }
        }
        .alert("Restore from iCloud?", isPresented: $showRestoreConfirmation) {
            Button("Restore", role: .destructive) { performRestore() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will add all blocks and settings from your iCloud backup. Existing data will not be removed, but duplicate blocks may be created if the backup overlaps with current data.")
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("About iCloud Backup")
                        .font(.title3)
                        .bold()
                    Text("iCloud Backup is the only feature in BlockErrn that sends your data off-device. When enabled, a copy of your blocks, expenses, audit history, and settings is uploaded to your personal iCloud storage managed by Apple.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 8) {
                disclaimerBullet("Your data is encrypted in transit and at rest by Apple's iCloud infrastructure.")
                disclaimerBullet("Only you can access your iCloud backup through your Apple ID.")
                disclaimerBullet("BlockErrn never sends data to any third-party server — iCloud is the sole exception when you enable this feature.")
                disclaimerBullet("You can disable iCloud Backup at any time and your local data is unaffected.")
            }
        }
        .flexErrnCardStyle()
    }

    private func disclaimerBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 3)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Toggle

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { iCloudManager.isEnabled },
                set: { iCloudManager.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable iCloud Backup")
                        .font(.headline)
                    Text(iCloudManager.iCloudAvailable
                         ? "Automatically backs up when you create a local backup or the app enters the background."
                         : "iCloud is not available. Sign in to iCloud in Settings to use this feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .tint(.accentColor)
            .disabled(!iCloudManager.iCloudAvailable)
        }
        .flexErrnCardStyle()
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup Status")
                .font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last iCloud backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(lastBackupText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(lastBackupColor)
                }
                Spacer()
                if iCloudManager.isUploading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = iCloudManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .flexErrnCardStyle()
    }

    // MARK: - Backup Now

    private var backupNowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Backup")
                .font(.headline)
            Text("Trigger an immediate iCloud backup of all your data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                performManualBackup()
            } label: {
                HStack(spacing: 8) {
                    if iCloudManager.isUploading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Label(iCloudManager.isUploading ? "Uploading..." : "Backup to iCloud Now",
                          systemImage: "icloud.and.arrow.up")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(iCloudManager.isUploading || !iCloudManager.iCloudAvailable)
            if let message = backupMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(backupMessageStyle.color)
                    .multilineTextAlignment(.center)
            }
        }
        .flexErrnCardStyle()
    }

    // MARK: - Restore

    private var restoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Restore from iCloud")
                        .font(.title3)
                        .bold()
                    if remoteBackupExists {
                        if let date = remoteBackupDate {
                            Text("Backup found from \(Self.dateFormatter.string(from: date))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Backup found in iCloud")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("No iCloud backup found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }
            Button {
                showRestoreConfirmation = true
            } label: {
                Label(iCloudManager.isDownloading ? "Downloading..." : "Restore from iCloud", systemImage: "arrow.down.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(!remoteBackupExists || iCloudManager.isDownloading)
            if let message = restoreMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(restoreMessageStyle.color)
                    .multilineTextAlignment(.center)
            }
        }
        .flexErrnCardStyle()
    }

    // MARK: - Helpers

    private var lastBackupText: String {
        guard let date = iCloudManager.lastBackupDate else { return "Never" }
        return Self.dateFormatter.string(from: date)
    }

    private var lastBackupColor: Color {
        guard let date = iCloudManager.lastBackupDate else { return .red }
        let age = Date().timeIntervalSince(date)
        let day: TimeInterval = 24 * 60 * 60
        if age <= 6 * day { return .green }
        if age <= 13 * day { return .yellow }
        return .red
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func checkForRemoteBackup() {
        iCloudManager.hasICloudBackup { exists, date in
            remoteBackupExists = exists
            remoteBackupDate = date
        }
    }

    private func performManualBackup() {
        backupMessage = nil
        let jsonData = makeBackupJSON()
        guard let data = jsonData else {
            backupMessage = "Failed to create backup data"
            backupMessageStyle = .error
            return
        }
        iCloudManager.uploadBackup(jsonData: data)
        backupMessage = "Backup started"
        backupMessageStyle = .info
    }

    private func performRestore() {
        restoreMessage = nil
        iCloudManager.downloadBackup { result in
            switch result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let payload = try decoder.decode(ICloudBackupPayload.self, from: data)
                    try importICloudBackup(payload)
                    iCloudManager.isEnabled = true
                    restoreMessage = "Restore complete. Your data has been imported."
                    restoreMessageStyle = .success
                } catch {
                    restoreMessage = "Restore failed: \(error.localizedDescription)"
                    restoreMessageStyle = .error
                }
            case .failure(let error):
                restoreMessage = "Restore failed: \(error.localizedDescription)"
                restoreMessageStyle = .error
            }
        }
    }

    private func makeBackupJSON() -> Data? {
        let blockPayloads = blocks.map { block in
            ICloudBlockPayload(
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
                    ICloudExpensePayload(
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
                    ICloudAuditEntryPayload(
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
                userCompletionTime: block.userCompletionTime,
                packageCount: block.packageCount,
                stopCount: block.stopCount
            )
        }

        let settingsPayloads = settings.map { setting in
            ICloudAppSettingsPayload(
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

        let payload = ICloudBackupPayload(blocks: blockPayloads, settings: settingsPayloads)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    private func importICloudBackup(_ payload: ICloudBackupPayload) throws {
        let existingBlockIDs = Set(blocks.map(\.id))

        for blockPayload in payload.blocks {
            guard !existingBlockIDs.contains(blockPayload.id) else { continue }
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
                updatedAt: blockPayload.updatedAt,
                startTime: blockPayload.startTime,
                endTime: blockPayload.endTime,
                userStartTime: blockPayload.userStartTime,
                userCompletionTime: blockPayload.userCompletionTime,
                packageCount: blockPayload.packageCount,
                stopCount: blockPayload.stopCount
            )
            block.routePoints = blockPayload.routePoints

            for expensePayload in blockPayload.expenses {
                let expense = Expense(
                    id: expensePayload.id,
                    categoryRaw: expensePayload.categoryRaw,
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

        // Only restore settings if none exist locally
        if settings.isEmpty {
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
        }

        try context.save()
    }
}

// MARK: - iCloud Backup Payload types

struct ICloudBackupPayload: Codable {
    let blocks: [ICloudBlockPayload]
    let settings: [ICloudAppSettingsPayload]
}

struct ICloudBlockPayload: Codable {
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
    let expenses: [ICloudExpensePayload]
    let auditEntries: [ICloudAuditEntryPayload]
    let startTime: Date?
    let endTime: Date?
    let routePoints: [RoutePoint]?
    let userStartTime: Date?
    let userCompletionTime: Date?
    let packageCount: Int?
    let stopCount: Int?
}

struct ICloudExpensePayload: Codable {
    let id: UUID
    let categoryRaw: String
    let amount: Decimal
    let note: String?
    let createdAt: Date
    let updatedAt: Date?
    let receiptFileName: String?
    let receiptData: Data?
}

struct ICloudAuditEntryPayload: Codable {
    let id: UUID
    let timestamp: Date
    let action: String
    let field: String?
    let oldValue: String?
    let newValue: String?
    let note: String?
}

struct ICloudAppSettingsPayload: Codable {
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
