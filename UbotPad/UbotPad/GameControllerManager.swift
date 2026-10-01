import Foundation
import GameController
import TouchController
import os


@Observable
@MainActor
final class GameControllerManager {
    private(set) var packet = ControlPacket()
    private(set) var controllerName: String?
    
    @ObservationIgnored
    weak var touchController: TCTouchController? {
        willSet {
            if self.physicalController == nil {
                newValue?.connect()
            }
        }
    }

    @ObservationIgnored
    private weak var activeController: GCController?

    /// The most recently connected physical (non-touch) controller, kept even while the
    /// TouchController is active so we know what to fall back to / prefer.
    @ObservationIgnored
    private weak var physicalController: GCController?

    /// The TouchController's own virtual GCController, once it has connected.
    @ObservationIgnored
    private weak var touchVirtualController: GCController?

    /// Observation ends automatically when these tokens are released.
    @ObservationIgnored
    private var observers: [NotificationCenter.ObservationToken] = []

    init() {
        observers.append(
            NotificationCenter.default.addObserver(
                of: GCController.self, for: .didConnect
            ) { [weak self] message in
                self?.controllerDidConnect(message.controller)
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                of: GCController.self, for: .didDisconnect
            ) { [weak self] message in
                self?.controllerDidDisconnect(message.controller)
            }
        )

        GCController.startWirelessControllerDiscovery(completionHandler: nil)

        if let controller = preferredPhysicalController() {
            controllerDidConnect(controller)
        }
    }

    /// Called when the user touches the on-screen pad: the TouchController regains
    /// control (and hides the physical controller's grip on `packet`) immediately,
    /// without waiting for a touch to actually move a stick.
    func userDidTouchScreen() {
        touchController?.connect()
        if let touchVirtualController {
            switchActive(to: touchVirtualController)
        }
    }

    private func controllerDidConnect(_ controller: GCController) {
        if controller.isTouchController() {
            attachHandler(controller)
            touchVirtualController = controller
            switchActive(to: controller)
            return
        }

        guard physicalController == nil else {
            // A physical controller is already connected; ignore any others that connect
            // until it disconnects.
            return
        }

        // A physical controller always takes priority over the on-screen TouchController.
        // `GCController.current` is the system's own notion of the most recently used
        // controller, so prefer it over the one that merely happened to fire this
        // particular connect notification.
        let preferred = preferredPhysicalController() ?? controller
        physicalController = preferred
        attachHandler(preferred)
        switchActive(to: preferred)
    }

    private func controllerDidDisconnect(_ controller: GCController) {
        let wasActive = controller === activeController

        if controller.isTouchController() {
            if touchVirtualController === controller { touchVirtualController = nil }
        } else if controller === physicalController {
            physicalController = nil

            // A previously-ignored physical controller, if any, now becomes the preferred one.
            if let fallback = preferredPhysicalController(excluding: controller) {
                physicalController = fallback
                attachHandler(fallback)
            }
        }

        guard wasActive else { return }

        if let physicalController {
            switchActive(to: physicalController)
        } else {
            activeController = nil
            controllerName = nil
            packet = ControlPacket()
            touchController?.connect()
        }
    }

    /// The physical controller to prefer among currently connected ones: `GCController.current`
    /// (the system's own notion of the most recently used controller) when it's set and not
    /// the on-screen TouchController, otherwise the most recently connected physical controller.
    private func preferredPhysicalController(excluding excluded: GCController? = nil) -> GCController? {
        if let current = GCController.current, !current.isTouchController(), current !== excluded {
            return current
        }
        return GCController.controllers().last(where: { !$0.isTouchController() && $0 !== excluded })
    }

    /// Installs the handler that both feeds `packet` and re-promotes this controller to
    /// active whenever it reports fresh input — e.g. the user pressing a button on a
    /// physical controller while the TouchController is currently active.
    private func attachHandler(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.valueChangedHandler = { [weak self] gamepad, _ in
            Task { @MainActor in
                self?.switchActive(to: controller)
                self?.update(from: gamepad)
            }
        }
    }

    /// Makes `controller` the one driving `packet`, hiding the on-screen TouchController
    /// UI whenever a physical controller takes over.
    private func switchActive(to controller: GCController) {
        guard activeController !== controller else { return }

        activeController = controller
        controllerName = controller.vendorName ?? "N/A"
        if !controller.isTouchController() {
            touchController?.disconnect()
        }
        if let gamepad = controller.extendedGamepad {
            update(from: gamepad)
        }
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


extension GCController {
    static let TOUCH_CONTROLLER_NAME: String = "Touch Controller"

    func isTouchController() -> Bool {
        return self.productCategory == GCController.TOUCH_CONTROLLER_NAME && self.vendorName == GCController.TOUCH_CONTROLLER_NAME
    }
}
