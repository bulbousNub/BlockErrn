import Foundation
import WatchConnectivity
import SwiftData
import Combine

/// iPhone-side WatchConnectivity manager.
/// Receives commands from the Watch, executes them via existing singletons,
/// and pushes state snapshots back to the Watch.
@MainActor
final class PhoneWatchSessionManager: NSObject, ObservableObject {
    static let shared = PhoneWatchSessionManager()

    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    private var mileUpdateTimer: Timer?

    private let context = ModelStorage.shared.context

    private override init() {
        super.init()
    }

    // MARK: - Activation

    private var isActivated = false

    func activateSession() {
        guard !isActivated else { return }
        guard WCSession.isSupported() else {
            print("Phone: WCSession not supported")
            return
        }
        isActivated = true
        let wc = WCSession.default
        wc.delegate = self
        wc.activate()
        session = wc
        print("Phone: WCSession activating, paired=\(wc.isPaired), watchAppInstalled=\(wc.isWatchAppInstalled), reachable=\(wc.isReachable)")
        observeStateChanges()
    }

    // MARK: - State Observation

    private func observeStateChanges() {
        let tracker = MileageTracker.shared
        let coordinator = WorkModeCoordinator.shared

        tracker.$isTracking
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isTracking in
                self?.handleTrackingStateChanged(isTracking)
            }
            .store(in: &cancellables)

        tracker.$currentBlockID
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushStateToWatch()
            }
            .store(in: &cancellables)

        coordinator.$forcedActiveBlockIDs
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushStateToWatch()
            }
            .store(in: &cancellables)

        coordinator.$blockToStart
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushStateToWatch()
            }
            .store(in: &cancellables)

        coordinator.$blockToStop
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushStateToWatch()
            }
            .store(in: &cancellables)
    }

    private func handleTrackingStateChanged(_ isTracking: Bool) {
        if isTracking {
            startMileUpdateTimer()
        } else {
            stopMileUpdateTimer()
        }
        pushStateToWatch()
    }

    private func startMileUpdateTimer() {
        stopMileUpdateTimer()
        mileUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pushStateToWatch()
            }
        }
    }

    private func stopMileUpdateTimer() {
        mileUpdateTimer?.invalidate()
        mileUpdateTimer = nil
    }

    // MARK: - Push State to Watch

    func pushStateToWatch() {
        guard let session, session.activationState == .activated else {
            print("Phone: pushStateToWatch skipped - session not activated")
            return
        }
        let snapshot = buildStateSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else {
            print("Phone: pushStateToWatch - failed to encode snapshot")
            return
        }
        print("Phone: pushStateToWatch - \(snapshot.activeBlocks.count) active, \(snapshot.upcomingBlocks.count) upcoming, reachable=\(session.isReachable)")

        // Always update applicationContext so Watch gets state even when not reachable
        do {
            try session.updateApplicationContext([WatchMessageKey.stateSnapshot: data])
            print("Phone: Updated applicationContext (\(data.count) bytes)")
        } catch {
            print("Phone: Failed to update applicationContext: \(error)")
        }

        // Also send live message if reachable for immediate update
        if session.isReachable {
            let message: [String: Any] = [WatchMessageKey.stateSnapshot: data]
            session.sendMessage(message, replyHandler: nil) { error in
                print("Phone: sendMessage failed: \(error)")
            }
        }
    }

    private func buildStateSnapshot() -> WatchStateSnapshot {
        let descriptor = FetchDescriptor<Block>(sortBy: [SortDescriptor(\.date)])
        let blocks = (try? context.fetch(descriptor)) ?? []
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = (try? context.fetch(settingsDescriptor)) ?? []
        let irsRate = settings.first?.irsMileageRate ?? Decimal(0.70)

        let now = Date()
        let forcedIDs = WorkModeCoordinator.shared.forcedActiveBlockIDs
        let window = now.addingTimeInterval(45 * 60)
        let twoDays = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now

        let activeBlocks = blocks.filter { block in
            guard block.status == .accepted else { return false }
            let start = block.scheduledStartDate
            let end = block.scheduledEndDate
            return (start <= window && end > now) || forcedIDs.contains(block.id)
        }

        let activeIDs = Set(activeBlocks.map(\.id))
        let upcomingBlocks = blocks.filter { block in
            guard block.status == .accepted else { return false }
            let start = block.scheduledStartDate
            return start > now && start <= twoDays && !activeIDs.contains(block.id)
        }

        let tracker = MileageTracker.shared
        let workModeBlockID: UUID? = {
            if tracker.isTracking, let id = tracker.currentBlockID {
                return id
            }
            return forcedIDs.first(where: { id in activeBlocks.contains(where: { $0.id == id }) })
        }()

        return WatchStateSnapshot(
            activeBlocks: activeBlocks.map { makeSummary($0) },
            upcomingBlocks: upcomingBlocks.map { makeSummary($0) },
            isTracking: tracker.isTracking,
            trackingBlockID: tracker.currentBlockID,
            currentMiles: tracker.currentMiles,
            workModeBlockID: workModeBlockID,
            irsRate: (irsRate as NSDecimalNumber).stringValue,
            timestamp: Date()
        )
    }

    private func makeSummary(_ block: Block) -> WatchBlockSummary {
        WatchBlockSummary(
            id: block.id,
            date: block.date,
            startTime: block.startTime,
            endTime: block.endTime,
            durationMinutes: block.durationMinutes,
            grossBase: (block.grossBase as NSDecimalNumber).stringValue,
            tipsAmount: block.tipsAmount.map { ($0 as NSDecimalNumber).stringValue },
            grossPayout: (block.grossPayout as NSDecimalNumber).stringValue,
            miles: (block.miles as NSDecimalNumber).stringValue,
            irsRateSnapshot: (block.irsRateSnapshot as NSDecimalNumber).stringValue,
            mileageDeduction: (block.mileageDeduction as NSDecimalNumber).stringValue,
            additionalExpensesTotal: (block.additionalExpensesTotal as NSDecimalNumber).stringValue,
            totalProfit: (block.totalProfit as NSDecimalNumber).stringValue,
            statusRaw: block.statusRaw,
            packageCount: block.packageCount,
            stopCount: block.stopCount,
            userStartTime: block.userStartTime,
            userCompletionTime: block.userCompletionTime,
            isEligibleForMakeActive: block.isEligibleForMakeActive,
            routePointsEncoded: block.routePointsData,
            notes: block.notes
        )
    }

    // MARK: - Command Handling

    private func handleCommand(_ commandMessage: WatchCommandMessage, replyHandler: (([String: Any]) -> Void)?) {
        switch commandMessage.command {
        case .startBlock:
            handleStartBlock(commandMessage.blockID)
        case .stopTracking:
            handleStopTracking(commandMessage.blockID)
        case .startTracking:
            handleStartTracking(commandMessage.blockID)
        case .completeBlock:
            handleCompleteBlock(commandMessage.blockID)
        case .createBlock:
            handleCreateBlock(commandMessage.params)
        case .makeActive:
            handleMakeActive(commandMessage.blockID)
        case .updatePackageCount:
            handleUpdatePackageCount(commandMessage.blockID, params: commandMessage.params)
        case .updateStopCount:
            handleUpdateStopCount(commandMessage.blockID, params: commandMessage.params)
        case .requestSync:
            break // just push state below
        }

        pushStateToWatch()
        replyHandler?([WatchMessageKey.success: true])
    }

    private func fetchBlock(_ blockID: UUID?) -> Block? {
        guard let blockID else { return nil }
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.id == blockID })
        return try? context.fetch(descriptor).first
    }

    private func handleStartBlock(_ blockID: UUID?) {
        guard let block = fetchBlock(blockID), block.status == .accepted else { return }
        let tracker = MileageTracker.shared

        let startTime = block.userStartTime ?? Date()
        if block.userStartTime == nil {
            block.userStartTime = startTime
            block.recordAuditEntry(
                action: .updated,
                field: "userStartTime",
                newValue: auditDateString(startTime),
                note: "Started via Apple Watch"
            )
        }
        try? context.save()

        let alreadyTracking = tracker.isTracking && tracker.currentBlockID == block.id
        if !alreadyTracking {
            tracker.requestAuthorization()
            tracker.startTracking(for: block.id)
            LiveActivityManager.shared.startActivity(
                blockID: block.id,
                scheduledStart: block.scheduledStartDate,
                scheduledEnd: block.scheduledEndDate
            )
        }

        WorkModeCoordinator.shared.startManually(block)
    }

    private func handleStopTracking(_ blockID: UUID?) {
        guard let block = fetchBlock(blockID) else { return }
        let tracker = MileageTracker.shared
        if let (sessionMiles, routePoints) = tracker.stopTracking(for: block.id) {
            let oldMiles = block.miles
            block.miles += Decimal(sessionMiles)
            block.appendRouteSegment(routePoints)
            block.recordAuditEntry(
                action: .milesUpdated,
                field: "miles",
                oldValue: auditDecimalString(oldMiles),
                newValue: auditDecimalString(block.miles),
                note: "Tracking paused via Apple Watch"
            )
            block.updatedAt = Date()
            try? context.save()
            LiveActivityManager.shared.updateMiles(NSDecimalNumber(decimal: block.miles).doubleValue)
        }
    }

    private func handleStartTracking(_ blockID: UUID?) {
        guard let block = fetchBlock(blockID) else { return }
        let tracker = MileageTracker.shared
        tracker.requestAuthorization()
        tracker.startTracking(for: block.id)
    }

    private func handleCompleteBlock(_ blockID: UUID?) {
        guard let block = fetchBlock(blockID) else { return }
        let tracker = MileageTracker.shared

        // Stop tracking if active
        if let (sessionMiles, routePoints) = tracker.stopTracking(for: block.id) {
            block.miles += Decimal(sessionMiles)
            block.appendRouteSegment(routePoints)
            block.recordAuditEntry(
                action: .milesUpdated,
                field: "miles",
                newValue: auditDecimalString(block.miles),
                note: "Captured via Apple Watch"
            )
        }

        LiveActivityManager.shared.endActivity(finalMiles: NSDecimalNumber(decimal: block.miles).doubleValue)

        block.userCompletionTime = Date()
        block.recordAuditEntry(
            action: .updated,
            field: "userCompletionTime",
            newValue: auditDateString(Date()),
            note: "Completed via Apple Watch"
        )
        block.status = .completed
        NotificationManager.shared.cancelNonTipReminders(for: block.id)
        block.recordAuditEntry(
            action: .statusChanged,
            field: "status",
            newValue: BlockStatus.completed.displayName
        )
        block.updatedAt = Date()
        try? context.save()

        WorkModeCoordinator.shared.stopManually(block)
    }

    private func handleCreateBlock(_ params: [String: String]?) {
        guard let params else { return }
        guard let dateStr = params["date"],
              let startStr = params["startTime"],
              let endStr = params["endTime"],
              let grossStr = params["grossBase"] else { return }

        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: dateStr),
              let startTime = isoFormatter.date(from: startStr),
              var endTime = isoFormatter.date(from: endStr),
              let grossBase = Decimal(string: grossStr) else { return }

        // Handle overnight blocks — Watch should already adjust, but be safe
        if endTime <= startTime {
            endTime = Calendar.current.date(byAdding: .day, value: 1, to: endTime) ?? endTime
        }

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = (try? context.fetch(settingsDescriptor)) ?? []
        let irsRate = settings.first?.irsMileageRate ?? Decimal(0.70)

        let duration = max(1, Int(endTime.timeIntervalSince(startTime) / 60))
        let block = Block(
            date: date,
            durationMinutes: duration,
            grossBase: grossBase,
            irsRateSnapshot: irsRate,
            startTime: startTime,
            endTime: endTime
        )
        block.auditEntries.append(AuditEntry(action: .created, note: "Block accepted from Apple Watch"))
        logBlockCreationFields(for: block, note: "Captured from Apple Watch", currencyFormatter: currencyString)
        context.insert(block)

        // Schedule reminders with default config
        let activeSettings = settings.first
        let reminderConfig = NotificationManager.ReminderConfiguration(
            startMinutes: activeSettings?.reminderBeforeStartMinutes ?? 45,
            preEndMinutes: activeSettings?.reminderBeforeEndMinutes ?? 15,
            tipHours: activeSettings?.tipReminderHours ?? 24,
            startEnabled: true,
            preEndEnabled: activeSettings?.includePreReminder ?? true,
            endEnabled: true,
            tipEnabled: false,
            hasTips: false
        )
        NotificationManager.shared.scheduleBlockReminders(for: block, config: reminderConfig)
        try? context.save()
    }

    private func handleMakeActive(_ blockID: UUID?) {
        guard let block = fetchBlock(blockID) else { return }
        WorkModeCoordinator.shared.forceActive(block)
    }

    private func handleUpdatePackageCount(_ blockID: UUID?, params: [String: String]?) {
        guard let block = fetchBlock(blockID),
              let valueStr = params?["value"],
              let value = Int(valueStr) else { return }
        block.packageCount = value
        block.updatedAt = Date()
        try? context.save()
    }

    private func handleUpdateStopCount(_ blockID: UUID?, params: [String: String]?) {
        guard let block = fetchBlock(blockID),
              let valueStr = params?["value"],
              let value = Int(valueStr) else { return }
        block.stopCount = value
        block.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Phone: activationDidComplete state=\(activationState.rawValue) error=\(String(describing: error)) reachable=\(session.isReachable)")
        if activationState == .activated {
            Task { @MainActor in
                print("Phone: Pushing initial state to Watch")
                self.pushStateToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processIncomingMessage(message, replyHandler: nil)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        processIncomingMessage(message, replyHandler: replyHandler)
    }

    private nonisolated func processIncomingMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        print("Phone: Received message with keys: \(message.keys)")
        let payloadKey = "commandPayload"
        let errorKey = "error"
        guard let data = message[payloadKey] as? Data else {
            print("Phone: No commandPayload in message")
            replyHandler?([errorKey: "Missing command payload"])
            return
        }
        Task { @MainActor in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let commandMessage = try? decoder.decode(WatchCommandMessage.self, from: data) else {
                print("Phone: Failed to decode WatchCommandMessage")
                replyHandler?([WatchMessageKey.error: "Invalid command"])
                return
            }
            print("Phone: Handling command: \(commandMessage.command)")
            self.handleCommand(commandMessage, replyHandler: replyHandler)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        print("Phone: reachabilityDidChange reachable=\(session.isReachable)")
        Task { @MainActor in
            self.pushStateToWatch()
        }
    }
}
