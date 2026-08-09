import Foundation
import GameController
import TouchController
import os


struct TouchStickState: Equatable {
    static let zero = TouchStickState(lx: 0, ly: 0)

    var lx: Float = 0
    var ly: Float = 0
}

/*
 @Observable
 @MainActor
 final class TouchControllerManager {
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
*/

@Observable
@MainActor
final class GameControllerManager {
    private(set) var packet = ControlPacket()
    private(set) var controllerName: String?

    weak var touchController: TCTouchController?

    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect, object: nil, queue: .main
            ) { [weak self] note in
                guard let controller = note.object as? GCController else { return }
                Task { @MainActor [weak self] in
                    self?.attach(controller)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect, object: nil, queue: .main
            ) { [weak self] note in
                guard let controller = note.object as? GCController else { return }
                Task { @MainActor [weak self] in
                    self?.detach(controller)
                }
            }
        )

        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        if let controller = GCController.controllers().first(where: { [weak self] in self?.isPhysical($0) ?? true }) {
            attach(controller)
        } else {
            if (TCTouchController.isSupported) {
                // TODO: attach touch controller
            }
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.observers.forEach(NotificationCenter.default.removeObserver)
        }
    }

    private func isPhysical(_ controller: GCController) -> Bool {
        // controller !== touchController?.virtualController
        return false
    }

    private func attach(_ controller: GCController) {
        guard isPhysical(controller) else { return }

        controllerName = controller.vendorName ?? "Controller"
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.valueChangedHandler = { [weak self] gamepad, _ in
            Task { @MainActor in
                self?.update(from: gamepad)
            }
        }
        update(from: gamepad)
    }

    private func detach(_ controller: GCController) {
        guard isPhysical(controller) else { return }
        
        if (TCTouchController.isSupported) {
            // TODO: attach virtual controller
        }

        controllerName = nil
        packet = ControlPacket()
    }

    private func update(from gamepad: GCExtendedGamepad) {
        var mask: ButtonMask = []

        if gamepad.buttonA.isPressed { mask.insert(.a) }
        if gamepad.buttonB.isPressed { mask.insert(.b) }
        if gamepad.buttonX.isPressed { mask.insert(.x) }
        if gamepad.buttonY.isPressed { mask.insert(.y) }
        if gamepad.leftShoulder.isPressed { mask.insert(.lb) }
        if gamepad.rightShoulder.isPressed { mask.insert(.rb) }
        if gamepad.buttonOptions?.isPressed == true { mask.insert(.view) }
        if gamepad.buttonMenu.isPressed { mask.insert(.menu) }
        if gamepad.buttonHome?.isPressed == true { mask.insert(.xbox) }
        if gamepad.leftThumbstickButton?.isPressed == true { mask.insert(.l3) }
        if gamepad.rightThumbstickButton?.isPressed == true { mask.insert(.r3) }

        let dpad: UInt8
        switch (gamepad.dpad.up.isPressed, gamepad.dpad.right.isPressed,
                gamepad.dpad.down.isPressed, gamepad.dpad.left.isPressed) {
        case (true, false, false, false): dpad = 0
        case (true, true, false, false): dpad = 1
        case (false, true, false, false): dpad = 2
        case (false, true, true, false): dpad = 3
        case (false, false, true, false): dpad = 4
        case (false, false, true, true): dpad = 5
        case (false, false, false, true): dpad = 6
        case (true, false, false, true): dpad = 7
        default: dpad = 0xF
        }

        packet = ControlPacket(
            lx: gamepad.leftThumbstick.xAxis.value,
            ly: gamepad.leftThumbstick.yAxis.value,
            rx: gamepad.rightThumbstick.xAxis.value,
            ry: gamepad.rightThumbstick.yAxis.value,
            lt: gamepad.leftTrigger.value,
            rt: gamepad.rightTrigger.value,
            buttons: mask,
            dpad: dpad
        )
    }
}
