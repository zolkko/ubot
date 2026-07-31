import Foundation
import GameController
import Combine

/// Reads an Xbox controller (or any `extendedGamepad`-profile controller) already paired
/// with the iPhone via iOS Bluetooth settings, and publishes its state as a `ControlPacket`.
@MainActor
final class GameControllerManager: ObservableObject {
    @Published private(set) var packet = ControlPacket()
    @Published private(set) var controllerName: String?

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
        if let controller = GCController.controllers().first {
            attach(controller)
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func attach(_ controller: GCController) {
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
