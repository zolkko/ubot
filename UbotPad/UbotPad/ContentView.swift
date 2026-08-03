import SwiftUI

struct ContentView: View {
    @StateObject private var gameController = GameControllerManager()
    @StateObject private var ble = BLEManager()

    var body: some View {
        VStack(spacing: 16) {
            statusBar
            distanceBar

            HStack(spacing: 24) {
                SpeedometerView(speed: abs(gameController.packet.ly), label: "LEFT TRACK")
                SpeedometerView(speed: abs(gameController.packet.ry), label: "RIGHT TRACK")
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: gameController.packet) { _, packet in
            ble.send(packet)
        }
    }

    private var statusBar: some View {
        HStack {
            Label(
                gameController.controllerName ?? "No controller",
                systemImage: gameController.controllerName == nil ? "gamecontroller.slash" : "gamecontroller.fill"
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
