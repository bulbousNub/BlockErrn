import Foundation

// MARK: - Block Summary (iPhone → Watch)

/// Lightweight Codable representation of a Block for Watch display.
/// Decimals are encoded as String for reliable cross-process serialization.
struct WatchBlockSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let durationMinutes: Int
    let grossBase: String
    let tipsAmount: String?
    let grossPayout: String
    let miles: String
    let irsRateSnapshot: String
    let mileageDeduction: String
    let additionalExpensesTotal: String
    let totalProfit: String
    let statusRaw: String
    let packageCount: Int?
    let stopCount: Int?
    let userStartTime: Date?
    let userCompletionTime: Date?
    let isEligibleForMakeActive: Bool
    let routePointsEncoded: Data?
    let notes: String?

    var scheduledStartDate: Date { startTime ?? date }

    var scheduledEndDate: Date {
        let effectiveStart = scheduledStartDate
        if let explicitEnd = endTime {
            var candidate = explicitEnd
            let calendar = Calendar.current
            while candidate <= effectiveStart {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate)
                    ?? candidate.addingTimeInterval(86400)
            }
            return candidate
        }
        let effectiveMinutes = max(1, durationMinutes)
        return effectiveStart.addingTimeInterval(TimeInterval(effectiveMinutes * 60))
    }

    var grossPayoutDecimal: Decimal {
        Decimal(string: grossPayout) ?? 0
    }

    var milesDecimal: Decimal {
        Decimal(string: miles) ?? 0
    }

    var mileageDeductionDecimal: Decimal {
        Decimal(string: mileageDeduction) ?? 0
    }

    var totalProfitDecimal: Decimal {
        Decimal(string: totalProfit) ?? 0
    }

    var additionalExpensesTotalDecimal: Decimal {
        Decimal(string: additionalExpensesTotal) ?? 0
    }

    var irsRateDecimal: Decimal {
        Decimal(string: irsRateSnapshot) ?? Decimal(0.70)
    }

    var grossBaseDecimal: Decimal {
        Decimal(string: grossBase) ?? 0
    }

    var tipsAmountDecimal: Decimal? {
        tipsAmount.flatMap { Decimal(string: $0) }
    }
}

// MARK: - Full State Snapshot (iPhone → Watch)

struct WatchStateSnapshot: Codable {
    let activeBlocks: [WatchBlockSummary]
    let upcomingBlocks: [WatchBlockSummary]
    let isTracking: Bool
    let trackingBlockID: UUID?
    let currentMiles: Double
    let workModeBlockID: UUID?
    let irsRate: String
    let timestamp: Date
}

// MARK: - Watch Commands (Watch → iPhone)

enum WatchCommand: String, Codable, Sendable {
    case startBlock
    case stopTracking
    case startTracking
    case completeBlock
    case createBlock
    case makeActive
    case requestSync
    case updatePackageCount
    case updateStopCount
}

struct WatchCommandMessage: Codable, Sendable {
    let command: WatchCommand
    let blockID: UUID?
    let params: [String: String]?
}

// MARK: - Message Keys

/// Constants for WatchConnectivity message keys.
enum WatchMessageKey {
    static let command = "watchCommand"
    static let stateSnapshot = "stateSnapshot"
    static let commandPayload = "commandPayload"
    static let commandResponse = "commandResponse"
    static let success = "success"
    static let error = "error"
}
