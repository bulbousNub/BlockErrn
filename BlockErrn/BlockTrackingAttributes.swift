import ActivityKit
import Foundation

struct BlockTrackingAttributes: ActivityAttributes {
    /// Static data — set once when the Live Activity starts
    let blockID: String
    let scheduledStart: Date
    let scheduledEnd: Date

    /// Dynamic data — updated as miles accumulate
    struct ContentState: Codable, Hashable {
        let currentMiles: Double
    }
}
