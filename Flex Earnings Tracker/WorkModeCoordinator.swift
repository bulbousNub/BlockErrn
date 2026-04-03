import Foundation
import Combine
import SwiftData

final class WorkModeCoordinator: ObservableObject {
    static let shared = WorkModeCoordinator()

    @Published var blockToStart: Block? = nil
    @Published var blockToStop: Block? = nil
    @Published private(set) var forcedActiveBlockIDs: Set<UUID> = []

    func startManually(_ block: Block) {
        forcedActiveBlockIDs.insert(block.id)
        blockToStart = block
    }

    func stopManually(_ block: Block) {
        forcedActiveBlockIDs.remove(block.id)
        blockToStop = block
    }

    func forceActive(_ block: Block) {
        forcedActiveBlockIDs.insert(block.id)
    }
    func remove(_ block: Block) {
        forcedActiveBlockIDs.remove(block.id)
    }
}
