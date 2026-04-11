import Foundation
import Combine

final class TabSelectionState: ObservableObject {
    @Published var selectedTab: Int = 0
}
