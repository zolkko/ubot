import Foundation
import Combine
import GameController


struct TouchStickState: Equatable {
    static let zero = TouchStickState(lx: 0, ly: 0)

    var lx: Float = 0
    var ly: Float = 0
}

@Observable
@MainActor
final class TouchControllerManager: ObservableObject {
    private(set) var state: TouchStickState = .zero

    private(set) var virtualController: GCController?

    func attachedVirtualController(_ controller: GCController) {
        virtualController = controller
    }

    func update(lx: Float, ly: Float) {
        // TODO: clamp lx and ly to -1..1
        state = TouchStickState(lx: lx, ly: ly)
    }
}
