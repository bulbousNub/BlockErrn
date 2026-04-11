import SwiftUI
import SwiftData
import CoreLocation
import CoreMotion
import UIKit
import UniformTypeIdentifiers

struct OnboardingView: View {
    @EnvironmentObject private var mileageTracker: MileageTracker
    @Environment(\.modelContext) private var context

    let appSettings: AppSettings
    let onComplete: () -> Void

    @State private var notificationPermissionGranted = false
    @State private var currentStep: Int = 0
    @State private var motionPermissionGranted = CMMotionActivityManager.authorizationStatus() == .authorized
    @State private var showLocalFileImporter = false
    @State private var restoreMessage: String?
    @State private var restoreMessageStyle: DataMessageStyle = .info
    @State private var iCloudBackupExists = false
    @State private var iCloudBackupDate: Date?
    @ObservedObject private var iCloudManager = ICloudBackupManager.shared

    @ObservedObject private var store = StoreKitManager.shared
    @State private var showProUpgrade = false
    private let steps = 7

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient
                .ignoresSafeArea()
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    stepContent(for: currentStep)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 10)
                .padding(.horizontal)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    stepIndicator

                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button("Back") {
                                currentStep -= 1
                            }
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                        }

                        Button(currentStep == steps - 1 ? "Let's go" : "Next") {
                            if currentStep == steps - 1 {
                                completeOnboarding()
                            } else {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.bottom, 32)
            }
            .animation(.none, value: currentStep)
        }
        .onChange(of: notificationPermissionGranted) { granted in
            if granted && currentStep == 3 {
                currentStep = 4
            }
        }
        .onChange(of: motionPermissionGranted) { granted in
            if granted && currentStep == steps - 1 {
                currentStep = steps - 1
            }
        }
        .onReceive(mileageTracker.$motionAuthorizationStatus) { status in
            motionPermissionGranted = (status == .authorized)
        }
        .onReceive(mileageTracker.$authorizationStatus) { status in
            if status == .authorizedAlways && currentStep == 4 {
                currentStep = 5
            }
        }
        .onAppear {
            ICloudBackupManager.shared.hasICloudBackup { exists, date in
                iCloudBackupExists = exists
                iCloudBackupDate = date
            }
        }
        .fileImporter(
            isPresented: $showLocalFileImporter,
            allowedContentTypes: [.json, .zip],
            allowsMultipleSelection: false
        ) { result in
            handleOnboardingLocalImport(result)
        }
    }

    private var introStep: some View {
        VStack(spacing: 14) {
            iconBadge("sparkles")
            Text("Welcome aboard, BlockErrn Drivers!")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .lineLimit(1)
            ForEach(introBullets, id: \.self) { bullet in
                BulletRow(text: bullet)
            }
        }
    }

    private var brandingStep: some View {
        VStack(spacing: 18) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 6)
            Text("BlockErrn")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.primary)
            Text("Your Earnings. Your Miles. Your Data.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notificationStep: some View {
        VStack(spacing: 12) {
            iconBadge("bell.fill")
            Text("Enable reminders")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            Text("We’ll remind you before every block ends, so you don’t forget to stop GPS tracking or wrap up expenses.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button(action: requestNotifications) {
                Label(notificationPermissionGranted ? "Notifications enabled" : "Turn on reminders", systemImage: notificationPermissionGranted ? "checkmark.bell" : "bell.badge")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(notificationPermissionGranted ? Color(.systemGreen) : Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(notificationPermissionGranted)
            Text(notificationPermissionGranted ? "Notifications processed on device and can be turned off at any time - we can't spam you even if we wanted to." : "iOS will ask permission to deliver helpful reminders tied to each block.")
                .font(.caption2)
                .foregroundStyle(notificationPermissionGranted ? .green : .secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var locationStep: some View {
        VStack(spacing: 10) {
            iconBadge("location.north.fill")
            Text("Why we need location")
                .font(.headline)
                .foregroundColor(.primary)
            Text("We use GPS to measure the miles you drive for each block and keep your earnings estimates accurate, even while BlockErrn runs in the background.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Button(action: requestAlways) {
                    Label(isAuthorizedAlways ? "Always allowed" : "Allow Always", systemImage: isAuthorizedAlways ? "checkmark.shield" : "location.north")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAuthorizedAlways ? Color(.systemGreen) : Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(isAuthorizedAlways)
                Text(locationStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(isAuthorizedAlways ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var motionStep: some View {
        VStack(spacing: 12) {
            iconBadge("car.fill")
            Text("Drive-only mileage")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            Text("Give BlockErrn access to motion data so it can tell when you’re actually in a vehicle, keeping the IRS mileage clean.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: requestMotionAuthorization) {
                Label(motionPermissionGranted ? "Motion enabled" : "Allow motion tracking", systemImage: motionPermissionGranted ? "checkmark.car" : "car")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(motionPermissionGranted ? Color(.systemGreen) : Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(motionPermissionGranted || !CMMotionActivityManager.isActivityAvailable())
            Text(motionStatusMessage)
                .font(.caption2)
                .foregroundStyle(motionPermissionGranted ? .green : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    @ViewBuilder private func stepContent(for step: Int) -> some View {
        switch step {
        case 0:
            brandingStep
        case 1:
            restoreStep
        case 2:
            introStep
        case 3:
            notificationStep
        case 4:
            locationStep
        case 5:
            motionStep
        case 6:
            proStep
        default:
            proStep
        }
    }

    private var restoreStep: some View {
        VStack(spacing: 12) {
            iconBadge("arrow.down.doc.fill")
            Text("Restore a backup?")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            Text("If you've used BlockErrn before, you can restore your data from an iCloud or local backup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if iCloudBackupExists {
                Button(action: restoreFromICloud) {
                    Label(
                        iCloudManager.isDownloading ? "Downloading..." : "Restore from iCloud",
                        systemImage: "icloud.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(iCloudManager.isDownloading)
                if let date = iCloudBackupDate {
                    Text("iCloud backup from \(Self.onboardingDateFormatter.string(from: date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.secondary)
                    Text("No iCloud backup found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: { showLocalFileImporter = true }) {
                Label("Restore from File", systemImage: "doc.zipper")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }

            if let message = restoreMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(restoreMessageStyle.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("You can skip this step if you're starting fresh.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private static let onboardingDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func restoreFromICloud() {
        restoreMessage = nil
        iCloudManager.downloadBackup { result in
            switch result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let payload = try decoder.decode(ICloudBackupPayload.self, from: data)
                    try importOnboardingBackup(payload)
                    iCloudManager.isEnabled = true
                    restoreMessage = "Restore complete! Your data has been imported."
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

    private func handleOnboardingLocalImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStop { url.stopAccessingSecurityScopedResource() }
                }
                let data: Data
                if url.pathExtension.lowercased() == "zip" {
                    guard let archive = Archive(url: url, accessMode: .read),
                          let entry = archive["BlockErrnBackup.json"] else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    var zipData = Data()
                    _ = try archive.extract(entry) { chunk in zipData.append(chunk) }
                    data = zipData
                } else {
                    data = try Data(contentsOf: url)
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(ICloudBackupPayload.self, from: data)
                try importOnboardingBackup(payload)
                restoreMessage = "Restored from \(url.lastPathComponent)"
                restoreMessageStyle = .success
            } catch {
                restoreMessage = "Import failed: \(error.localizedDescription)"
                restoreMessageStyle = .error
            }
        case .failure(let error):
            restoreMessage = "Import cancelled: \(error.localizedDescription)"
            restoreMessageStyle = .info
        }
    }

    private func importOnboardingBackup(_ payload: ICloudBackupPayload) throws {
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
                if let receiptData = expensePayload.receiptData {
                    let savedFile = ReceiptStorage.save(data: receiptData, fileName: expensePayload.receiptFileName)
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

        // Restore settings if this is a fresh install
        for settingPayload in payload.settings {
            appSettings.irsMileageRate = settingPayload.irsMileageRate
            appSettings.currencyCode = settingPayload.currencyCode
            appSettings.roundingScale = settingPayload.roundingScale
            appSettings.preferredAppearanceRaw = settingPayload.preferredAppearanceRaw
            appSettings.includePreReminder = settingPayload.includePreReminder ?? true
            appSettings.hasDismissedPlanCard = settingPayload.hasDismissedPlanCard ?? false
            appSettings.reminderBeforeStartMinutes = settingPayload.reminderBeforeStartMinutes ?? 45
            appSettings.reminderBeforeEndMinutes = settingPayload.reminderBeforeEndMinutes ?? 15
            appSettings.tipReminderHours = settingPayload.tipReminderHours ?? 24
            if let categories = settingPayload.expenseCategoryDescriptors {
                appSettings.expenseCategoryDescriptors = categories
            }
        }

        try context.save()
    }

    private var proStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 8, x: 0, y: 3)

            Text("BlockErrn Pro")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)

            Text("Unlock every feature")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Free features
            VStack(alignment: .leading, spacing: 6) {
                Text("Always included")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                freeFeatureRow("Block tracking")
                freeFeatureRow("Mileage GPS tracking")
                freeFeatureRow("Expense logging")
                freeFeatureRow("Current week trends")
                freeFeatureRow("Basic CSV export")
                freeFeatureRow("Local backup")
                freeFeatureRow("Apple Watch app")
                freeFeatureRow("CarPlay dashboard")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Pro-only feature list
            VStack(alignment: .leading, spacing: 6) {
                Text("Unlock with Pro")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                proFeatureRow("Receipt capture")
                proFeatureRow("Full trend history")
                proFeatureRow("iCloud backup")
                proFeatureRow("PDF reports")
                proFeatureRow("CSV column config")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                showProUpgrade = true
            } label: {
                Text("View Plans & Pricing")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.yellow)
            .foregroundColor(.black)

            HStack(spacing: 16) {
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)

                Text("·")
                    .foregroundStyle(.secondary)

                Text("1-week free trial on subscriptions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showProUpgrade) {
            NavigationStack {
                ProUpgradeView(isOnboarding: true)
            }
        }
    }

    private func freeFeatureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private func proFeatureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private func iconBadge(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 72, weight: .semibold))
            .frame(width: 96, height: 96)
            .background(Circle().fill(Color.accentColor))
            .clipShape(Circle())
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 20, height: 6)
            }
        }
    }

    private func requestNotifications() {
        NotificationManager.shared.requestAuthorization { granted in
            notificationPermissionGranted = granted
        }
    }

    private func requestAlways() {
        mileageTracker.requestAuthorization()
    }

    private func requestMotionAuthorization() {
        mileageTracker.requestMotionAuthorization()
    }

    private func completeOnboarding() {
        appSettings.hasCompletedOnboarding = true
        try? context.save()
        onComplete()
    }

    private var isAuthorizedAlways: Bool {
        mileageTracker.authorizationStatus == .authorizedAlways
    }

    private var locationStatusMessage: String {
        if isAuthorizedAlways {
            return "Background GPS is ready, so BlockErrn can keep counting miles even when the app leaves the foreground."
        } else {
            return "We might not track mileage properly unless location is allowed always. Tap the button above to enable full tracking."
        }
    }

    private var motionStatusMessage: String {
        switch mileageTracker.motionAuthorizationStatus {
        case .authorized:
            return "Motion updates are enabled, so we only count the time you are actually driving."
        case .denied, .restricted:
            return "Motion tracking is blocked. Open Settings → BlockErrn to allow vehicle detection."
        case .notDetermined:
            return "Grant access on the next screen so we can ignore walking when measuring mileage."
        @unknown default:
            return "Motion data access is not available on this device."
        }
    }

    private let introBullets = [
        "Track your Dollars - base pay, tips, mileage and other expenses.",
        "Track your Miles - processed on device using GPS or through manual entry.",
        "Local Notifications - On-Device reminders to finish tracking your miles and expenses near the end of your blocks.",
        "Trend Data - visualizations and insights into your earnings and expenses, processed locally. Export your data to use for whatever you'd like, it's your data.",
        "Everything happens on-device - no account, no back-end, no middlemen. Your data is YOUR data."
    ]

    private struct BulletRow: View {
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(.accentColor)
                    .padding(.top, 6)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
