import Foundation
import SwiftData

final class WorkModeCoordinator: ObservableObject {
    @Published var blockToStart: Block? = nil
    @Published private(set) var forcedActiveBlockIDs: Set<UUID> = []

    func startManually(_ block: Block) {
        forcedActiveBlockIDs.insert(block.id)
        blockToStart = block
    }

    func remove(_ block: Block) {
        forcedActiveBlockIDs.remove(block.id)
    }
}
