import SwiftUI
import TouchController


struct ContentView: View {
    @State private var touchController: TouchControllerManager
    @State private var gameController: GameControllerManager
    @State private var ble = BLEManager()

    init() {
        let touchController = TouchControllerManager()
        _touchController = State(wrappedValue: touchController)
        _gameController = State(wrappedValue: GameControllerManager(ignoring: touchController))
    }

    private var mergedPacket: ControlPacket {
        var packet = gameController.packet
        if gameController.controllerName == nil {
            packet.lx = touchController.state.lx
            packet.ly = touchController.state.ly
        }
        return packet
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                statusBar
                distanceBar

                HStack(spacing: 24) {
                    SpeedometerView(speed: abs(mergedPacket.ly), label: "l.joystick.tilt.left")
                    SpeedometerView(speed: abs(mergedPacket.ry), label: "r.joystick.tilt.right")
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemBackground))
            .onChange(of: gameController.packet) { _, _ in
                ble.send(mergedPacket)
            }
            .onChange(of: touchController.state) { _, _ in
                ble.send(mergedPacket)
            }

            if (TCTouchController.isSupported) {
                TouchPadView(manager: touchController, isEnabled: gameController.controllerName == nil)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Label(
                gameController.controllerName ?? "No controller",
                systemImage: gameController.controllerName == nil ? "minus.square" : "gamecontroller.fill"
            )
            .foregroundStyle(gameController.controllerName == nil ? .secondary : .primary)

            Spacer()

            Label(connectionLabel, systemImage: connectionIcon)
                .foregroundStyle(connectionColor)
        }
        .font(.headline)
    }

    private var connectionLabel: String {
        switch ble.state {
        case .poweredOff: return "Bluetooth off"
        case .scanning: return "Scanning for Ubot..."
        case .connecting: return "Connecting..."
        case .connected(let name): return "Connected: \(name)"
        case .disconnected: return "Disconnected"
        }
    }

    private var connectionIcon: String {
        switch ble.state {
        case .connected: return "antenna.radiowaves.left.and.right"
        default: return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var connectionColor: Color {
        switch ble.state {
        case .connected: return .green
        case .poweredOff: return .red
        default: return .secondary
        }
    }

    private var distanceBar: some View {
        HStack {
            Label(distanceLabel, systemImage: "sensor.tag.radiowaves.forward")
                .foregroundStyle(distanceColor)
            Spacer()
        }
        .font(.subheadline)
    }

    private var distanceLabel: String {
        guard let mm = ble.distanceMm else { return "Distance: --" }
        return String(format: "Distance: %.0f cm", Double(mm) / 10)
    }

    private var distanceColor: Color {
        guard let mm = ble.distanceMm else { return .secondary }
        return mm < 200 ? .red : .secondary
    }
}

#Preview {
    ContentView()
}
