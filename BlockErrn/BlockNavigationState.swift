import SwiftUI
import Combine

final class BlockNavigationState: ObservableObject {
    @Published var blockToOpen: Block?
}
