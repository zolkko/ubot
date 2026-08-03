//! Decodes the 9-byte control packet sent by the iOS companion app (see
//! `../UbotRemote/README.md` for the Swift side of this wire format). The iOS app reads
//! an Xbox controller via Apple's GameController framework and relays its state here
//! over a custom BLE GATT characteristic — so unlike raw HID reports, this layout is
//! fully our own and needs no reverse engineering or hardware calibration.
//!
//! Packet layout (little-endian, 9 bytes):
//!   byte 0: lx      i8   (-127..127)
//!   byte 1: ly      i8   (-127..127)
//!   byte 2: rx      i8   (-127..127)
//!   byte 3: ry      i8   (-127..127)
//!   byte 4: lt      u8   (0..255)
//!   byte 5: rt      u8   (0..255)
//!   byte 6: buttons_lo u8
//!   byte 7: buttons_hi u8
//!   byte 8: dpad    u8   (0..8, 0xF = none)

use bitflags::bitflags;

pub const PACKET_LEN: usize = 9;

#[derive(Default, Clone, Copy)]
#[repr(transparent)]
pub(crate) struct Packet {
    inner: [u8; PACKET_LEN],
}

impl From<[u8; PACKET_LEN]> for Packet {
    fn from(inner: [u8; PACKET_LEN]) -> Self {
        Self { inner }
    }
}

impl AsRef<[u8]> for Packet {
    fn as_ref(&self) -> &[u8] {
        &self.inner
    }
}

const AXIS_DEADZONE: f32 = 0.08;

bitflags! {
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub struct Buttons: u16 {
        const A          = 1 << 0;
        const B          = 1 << 1;
        const X          = 1 << 2;
        const Y          = 1 << 3;
        const LB         = 1 << 4;
        const RB         = 1 << 5;
        const VIEW       = 1 << 6;
        const MENU       = 1 << 7;
        const XBOX       = 1 << 8;
        const L3         = 1 << 9;
        const R3         = 1 << 10;
    }
}

impl Default for Buttons {
    fn default() -> Self {
        Buttons::empty()
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct GamepadState {
    /// -1.0 (left/up) .. 1.0 (right/down), deadzone applied
    pub lx: f32,
    pub ly: f32,
    pub rx: f32,
    pub ry: f32,
    /// 0.0 .. 1.0
    pub lt: f32,
    pub rt: f32,
    pub dpad: u8,
    pub buttons: Buttons,
}

impl From<Packet> for GamepadState {
    fn from(packet: Packet) -> Self {
        parse_packet(&packet.inner)
    }
}

fn axis(raw: i8) -> f32 {
    let v = raw as f32 / 127.0;
    if v.abs() < AXIS_DEADZONE {
        0.0
    } else {
        v.clamp(-1.0, 1.0)
    }
}

fn trigger(raw: u8) -> f32 {
    raw as f32 / 255.0
}

pub fn parse_packet(data: &[u8; PACKET_LEN]) -> GamepadState {
    GamepadState {
        lx: axis(data[0] as i8),
        ly: axis(data[1] as i8),
        rx: axis(data[2] as i8),
        ry: axis(data[3] as i8),
        lt: trigger(data[4]),
        rt: trigger(data[5]),
        buttons: Buttons::from_bits_truncate(u16::from_le_bytes([data[6], data[7]])),
        dpad: data[8],
    }
}
