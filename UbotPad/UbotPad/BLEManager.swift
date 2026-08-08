import Foundation
import CoreBluetooth


enum RobotConnectionState: Equatable {
    case poweredOff
    case scanning
    case connecting
    case connected(name: String)
    case disconnected
}

// TODO: need to integrate with ActivityKit ...

/// BLE central that scans for the "Ubot" peripheral (see `ubot-next/src/ble.rs`) and writes
/// `ControlPacket`s to its control characteristic. UUIDs here must match that file exactly.
@Observable
@MainActor
final class BLEManager: NSObject /*, ObservableObject */ {
    nonisolated static let serviceUUID = CBUUID(string: "6F0F6A4E-5A3B-4B8E-9B0A-1F2E3D4C5B6A")
    nonisolated static let controlCharUUID = CBUUID(string: "6F0F6A4E-5A3B-4B8E-9B0A-1F2E3D4C5B6B")
    nonisolated static let distanceCharUUID = CBUUID(string: "6F0F6A4E-5A3B-4B8E-9B0A-1F2E3D4C5B6C")

    /// Minimum spacing between writes so a fast-changing controller doesn't flood the link.
    private static let minSendInterval: TimeInterval = 1.0 / 30.0

    // published
    private(set) var state: RobotConnectionState = .disconnected

    // published
    /// Latest ultrasonic ranging reading from the robot, in millimeters. `nil` until the
    /// first notification arrives (or after a disconnect).
    private(set) var distanceMm: UInt16?

    private var central: CBCentralManager!
    private var robotPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var distanceCharacteristic: CBCharacteristic?
    private var lastSendTime: Date = .distantPast

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func send(_ packet: ControlPacket) {
        guard let characteristic = controlCharacteristic, let peripheral = robotPeripheral else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSendTime) >= Self.minSendInterval else { return }
        lastSendTime = now
        peripheral.writeValue(packet.data, for: characteristic, type: .withoutResponse)
    }

    private func startScanning() {
        state = .scanning
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }
}

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                startScanning()
            case .poweredOff, .unauthorized, .unsupported:
                state = .poweredOff
            default:
                break
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            central.stopScan()
            robotPeripheral = peripheral
            peripheral.delegate = self
            state = .connecting
            central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            controlCharacteristic = nil
            distanceCharacteristic = nil
            distanceMm = nil
            robotPeripheral = nil
            state = .disconnected
            startScanning()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            state = .disconnected
            startScanning()
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serviceUUID {
            peripheral.discoverCharacteristics([Self.controlCharUUID, Self.distanceCharUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.controlCharUUID:
                Task { @MainActor in
                    controlCharacteristic = characteristic
                    state = .connected(name: peripheral.name ?? "Ubot")
                }
            case Self.distanceCharUUID:
                Task { @MainActor in
                    distanceCharacteristic = characteristic
                }
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.distanceCharUUID,
              let data = characteristic.value, data.count >= 2
        else { return }
        let mm = UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
        Task { @MainActor in
            distanceMm = mm
        }
    }
}
