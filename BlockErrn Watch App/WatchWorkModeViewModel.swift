import Foundation
import Combine

/// Computes live derived values for the work mode view from the session manager state.
final class WatchWorkModeViewModel: ObservableObject {
    @Published var block: WatchBlockSummary?
    @Published var liveMiles: Double = 0
    @Published var isTracking: Bool = false
    @Published var packageCount: Int = 0
    @Published var stopCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private let sessionManager: WatchSessionManager

    init(sessionManager: WatchSessionManager = .shared) {
        self.sessionManager = sessionManager
        observeSession()
    }

    private func observeSession() {
        // Track the work mode block
        sessionManager.$workModeBlockID
            .combineLatest(sessionManager.$activeBlocks)
            .receive(on: RunLoop.main)
            .sink { [weak self] (blockID, blocks) in
                guard let self else { return }
                if let blockID {
                    self.block = blocks.first(where: { $0.id == blockID })
                    self.packageCount = self.block?.packageCount ?? 0
                    self.stopCount = self.block?.stopCount ?? 0
                } else {
                    self.block = nil
                }
            }
            .store(in: &cancellables)

        // Track live miles
        sessionManager.$currentMiles
            .receive(on: RunLoop.main)
            .assign(to: &$liveMiles)

        // Track GPS state
        sessionManager.$isTracking
            .receive(on: RunLoop.main)
            .assign(to: &$isTracking)
    }

    // MARK: - Computed Values

    var irsRateDecimal: Decimal {
        Decimal(string: sessionManager.irsRate) ?? Decimal(0.70)
    }

    var liveMileageDeduction: Decimal {
        // Round total miles to whole number using standard rounding (.5+ rounds up)
        // to match iOS CalculatorView behavior
        var totalMilesDecimal = totalMiles
        var roundedMiles = Decimal()
        NSDecimalRound(&roundedMiles, &totalMilesDecimal, 0, .plain)
        return roundedMiles * irsRateDecimal
    }

    var grossPayout: Decimal {
        block?.grossPayoutDecimal ?? 0
    }

    var totalProfit: Decimal {
        grossPayout - liveMileageDeduction - (block?.additionalExpensesTotalDecimal ?? 0)
    }

    var existingBlockMiles: Decimal {
        block?.milesDecimal ?? 0
    }

    var totalMiles: Decimal {
        existingBlockMiles + Decimal(liveMiles)
    }

    // MARK: - Commands

    func startTracking() {
        guard let blockID = block?.id else { return }
        sessionManager.sendCommand(.startTracking, blockID: blockID)
    }

    func stopTracking() {
        guard let blockID = block?.id else { return }
        sessionManager.sendCommand(.stopTracking, blockID: blockID)
    }

    func completeBlock() {
        guard let blockID = block?.id else { return }
        sessionManager.sendCommand(.completeBlock, blockID: blockID)
    }

    func updatePackageCount(_ value: Int) {
        guard let blockID = block?.id else { return }
        packageCount = value
        sessionManager.sendCommand(.updatePackageCount, blockID: blockID, params: ["value": "\(value)"])
    }

    func updateStopCount(_ value: Int) {
        guard let blockID = block?.id else { return }
        stopCount = value
        sessionManager.sendCommand(.updateStopCount, blockID: blockID, params: ["value": "\(value)"])
    }
}
