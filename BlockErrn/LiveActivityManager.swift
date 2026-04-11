import ActivityKit
import Foundation

final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<BlockTrackingAttributes>?
    private var lastUpdateTime: Date = .distantPast

    /// Minimum interval between Live Activity updates to avoid excessive refreshes
    private let updateInterval: TimeInterval = 5

    private init() {
        // Clean up any orphaned Live Activities from a previous app session.
        // If the app was killed or crashed while a Live Activity was running,
        // the Activity persists on the Lock Screen / Dynamic Island but
        // LiveActivityManager loses its in-memory reference. End them here.
        let orphaned = Activity<BlockTrackingAttributes>.activities
        if !orphaned.isEmpty {
            print("[LiveActivityManager] Cleaning up \(orphaned.count) orphaned Live Activities")
            for activity in orphaned {
                Task { await activity.end(activity.content, dismissalPolicy: .immediate) }
            }
        }
    }

    // MARK: - Start

    func startActivity(blockID: UUID, scheduledStart: Date, scheduledEnd: Date, initialMiles: Double = 0) {
        // End the tracked in-memory activity
        endActivity()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivityManager] Live Activities are NOT enabled — check Settings > BlockErrn > Live Activities")
            return
        }
        print("[LiveActivityManager] Live Activities enabled, requesting activity for block \(blockID)...")

        let attributes = BlockTrackingAttributes(
            blockID: blockID.uuidString,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd
        )

        let state = BlockTrackingAttributes.ContentState(currentMiles: initialMiles)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[LiveActivityManager] Successfully started Live Activity id=\(currentActivity?.id ?? "nil")")
        } catch {
            print("[LiveActivityManager] Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    func updateMiles(_ miles: Double) {
        guard let activity = currentActivity else { return }

        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= updateInterval else { return }
        lastUpdateTime = now

        let state = BlockTrackingAttributes.ContentState(currentMiles: miles)
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    // MARK: - End

    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = activity.content.state
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    /// End with a specific final miles value
    func endActivity(finalMiles: Double) {
        guard let activity = currentActivity else { return }

        let state = BlockTrackingAttributes.ContentState(currentMiles: finalMiles)
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: - Cleanup

    /// Ends all running BlockTrackingAttributes activities at the system level.
    /// Used to clean up orphaned activities from previous sessions.
    private func endAllActivities() {
        let existing = Activity<BlockTrackingAttributes>.activities
        guard !existing.isEmpty else { return }
        for activity in existing {
            // Skip the activity we're currently tracking — don't kill our own
            if let current = currentActivity, current.id == activity.id { continue }
            Task {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }
}
