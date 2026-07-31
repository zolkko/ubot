import Foundation

/// Wire format for the BLE control characteristic. Must match `ubot-next/src/gamepad.rs`
/// (`PACKET_LEN` / `parse_packet`) byte-for-byte.
///
/// Layout (little-endian, 9 bytes):
///   0: lx  Int8   1: ly  Int8   2: rx  Int8   3: ry  Int8
///   4: lt  UInt8  5: rt  UInt8
///   6: buttons_lo UInt8   7: buttons_hi UInt8
///   8: dpad UInt8 (0...8, 0xF = none)
struct ButtonMask: OptionSet {
    let rawValue: UInt16

    static let a     = ButtonMask(rawValue: 1 << 0)
    static let b     = ButtonMask(rawValue: 1 << 1)
    static let x     = ButtonMask(rawValue: 1 << 2)
    static let y     = ButtonMask(rawValue: 1 << 3)
    static let lb    = ButtonMask(rawValue: 1 << 4)
    static let rb    = ButtonMask(rawValue: 1 << 5)
    static let view  = ButtonMask(rawValue: 1 << 6)
    static let menu  = ButtonMask(rawValue: 1 << 7)
    static let xbox  = ButtonMask(rawValue: 1 << 8)
    static let l3    = ButtonMask(rawValue: 1 << 9)
    static let r3    = ButtonMask(rawValue: 1 << 10)
}

struct ControlPacket: Equatable {
    static let length = 9

    var lx: Float = 0   // -1...1
    var ly: Float = 0
    var rx: Float = 0
    var ry: Float = 0
    var lt: Float = 0   // 0...1
    var rt: Float = 0
    var buttons: ButtonMask = []
    var dpad: UInt8 = 0xF

    private func encodeAxis(_ v: Float) -> Int8 {
        Int8(max(-127, min(127, v * 127)))
    }

    private func encodeTrigger(_ v: Float) -> UInt8 {
        UInt8(max(0, min(255, v * 255)))
    }

    var data: Data {
        var bytes = [UInt8](repeating: 0, count: Self.length)
        bytes[0] = UInt8(bitPattern: encodeAxis(lx))
        bytes[1] = UInt8(bitPattern: encodeAxis(ly))
        bytes[2] = UInt8(bitPattern: encodeAxis(rx))
        bytes[3] = UInt8(bitPattern: encodeAxis(ry))
        bytes[4] = encodeTrigger(lt)
        bytes[5] = encodeTrigger(rt)
        bytes[6] = UInt8(buttons.rawValue & 0xFF)
        bytes[7] = UInt8((buttons.rawValue >> 8) & 0xFF)
        bytes[8] = dpad
        return Data(bytes)
    }

    /// Commanded speed magnitude in 0...1, used to drive the speedometer since the robot
    /// has no wheel encoders to report real velocity back.
    var commandedSpeed: Float {
        max(abs(ly), abs(ry))
    }
}
