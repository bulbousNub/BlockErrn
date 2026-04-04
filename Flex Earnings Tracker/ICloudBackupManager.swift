import Foundation
import Combine
import SwiftData

final class ICloudBackupManager: ObservableObject {
    static let shared = ICloudBackupManager()

    private static let backupFileName = "BlockErrnBackup.json"
    private static let backupFolderName = "BlockErrnBackups"
    private static let lastICloudBackupKey = "BlockErrnLastICloudBackupDate"
    private static let iCloudEnabledKey = "BlockErrnICloudBackupEnabled"

    @Published private(set) var isUploading = false
    @Published private(set) var isDownloading = false
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var iCloudAvailable = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.iCloudEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.iCloudEnabledKey)
            objectWillChange.send()
        }
    }

    private init() {
        loadLastBackupDate()
        checkAvailability()
    }

    // MARK: - Availability

    func checkAvailability() {
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Container URL

    private func backupDirectoryURL() -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let backupDir = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(Self.backupFolderName, isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupDir.path) {
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        return backupDir
    }

    private func backupFileURL() -> URL? {
        backupDirectoryURL()?.appendingPathComponent(Self.backupFileName)
    }

    // MARK: - Upload

    func uploadBackup(jsonData: Data) {
        guard isEnabled else { return }
        guard !isUploading else { return }

        isUploading = true
        lastError = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            do {
                guard let destinationURL = self.backupFileURL() else {
                    throw ICloudBackupError.containerUnavailable
                }
                try jsonData.write(to: destinationURL, options: .atomic)
                let now = Date()
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.lastBackupDate = now
                    self.recordLastBackupDate(now)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Download

    func downloadBackup(completion: @escaping (Result<Data, Error>) -> Void) {
        guard !isDownloading else {
            completion(.failure(ICloudBackupError.alreadyInProgress))
            return
        }

        isDownloading = true
        lastError = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            do {
                guard let fileURL = self.backupFileURL() else {
                    throw ICloudBackupError.containerUnavailable
                }

                // Check if the file is already fully downloaded
                if !self.isFileDownloaded(at: fileURL) {
                    // Trigger iCloud download — may throw if file doesn't exist at all
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

                    // Poll until the file is fully downloaded (up to 60 seconds)
                    var downloaded = false
                    for _ in 0..<120 {
                        if self.isFileDownloaded(at: fileURL) {
                            downloaded = true
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.5)
                    }

                    guard downloaded else {
                        throw ICloudBackupError.downloadTimeout
                    }
                }

                let data = try Data(contentsOf: fileURL)
                DispatchQueue.main.async {
                    self.isDownloading = false
                    completion(.success(data))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.lastError = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Returns true only when the file exists locally with its full content (not an iCloud placeholder).
    private func isFileDownloaded(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = values.ubiquitousItemDownloadingStatus {
                return status == .current
            }
            // If the key isn't present the file isn't managed by iCloud — treat as local
            return true
        } catch {
            return false
        }
    }

    // MARK: - Check if backup exists

    func hasICloudBackup(completion: @escaping (Bool, Date?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self,
                  let fileURL = self.backupFileURL() else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            let fm = FileManager.default
            let exists = fm.fileExists(atPath: fileURL.path)
            var modDate: Date?
            if exists {
                modDate = (try? fm.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
            }
            DispatchQueue.main.async { completion(exists, modDate) }
        }
    }

    // MARK: - Persistence

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: Self.lastICloudBackupKey) as? Date
    }

    private func recordLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastICloudBackupKey)
    }
}

// MARK: - Auto-backup helper for app background

@MainActor
enum ICloudAutoBackup {
    static func performIfEnabled(container: ModelContainer) {
        let manager = ICloudBackupManager.shared
        guard manager.isEnabled, manager.iCloudAvailable, !manager.isUploading else { return }

        let context = container.mainContext
        let blockDescriptor = FetchDescriptor<Block>(sortBy: [SortDescriptor(\.date)])
        let settingsDescriptor = FetchDescriptor<AppSettings>()

        guard let blocks = try? context.fetch(blockDescriptor),
              let settings = try? context.fetch(settingsDescriptor) else { return }

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
        guard let data = try? encoder.encode(payload) else { return }
        manager.uploadBackup(jsonData: data)
    }
}

enum ICloudBackupError: LocalizedError {
    case containerUnavailable
    case alreadyInProgress
    case downloadTimeout
    case noBackupFound

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "iCloud is not available. Check that you are signed in to iCloud in Settings."
        case .alreadyInProgress:
            return "A backup operation is already in progress."
        case .downloadTimeout:
            return "The iCloud backup could not be downloaded in time. Check your internet connection and try again."
        case .noBackupFound:
            return "No iCloud backup was found."
        }
    }
}
