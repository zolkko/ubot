//! Maps controller input to tank-drive motor commands and reacts to button presses.
//!
//! Controls:
//!   Left stick Y  -> left track speed/direction
//!   Right stick Y -> right track speed/direction
//!   Right trigger -> speed boost multiplier (1.0x .. 2.0x)
//!   A             -> latch emergency stop (motors forced to zero)
//!   B             -> release emergency stop

use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Receiver;

use crate::gamepad::{Buttons, GamepadState};
use crate::motors::TrackDrive;

const BASE_SPEED_LIMIT: f32 = 0.85;

pub async fn run(
    receiver: Receiver<'static, ThreadModeRawMutex, GamepadState, 8>,
    mut drive: TrackDrive<'static>,
) -> ! {
    drive.enable();
    let mut estopped = false;

    loop {
        let state = receiver.receive().await;

        if state.buttons.contains(Buttons::A) {
            estopped = true;
        }
        if state.buttons.contains(Buttons::B) {
            estopped = false;
        }

        if estopped {
            drive.disable();
            continue;
        }
        drive.enable();

        let boost = 1.0 + state.rt; // up to 2x with right trigger fully pressed
        let limit = BASE_SPEED_LIMIT * boost.min(2.0) / 2.0 + BASE_SPEED_LIMIT * 0.5;

        // Stick Y is typically up = negative on HID axes; flip so pushing up drives forward.
        let left = (-state.ly * limit).clamp(-1.0, 1.0);
        let right = (-state.ry * limit).clamp(-1.0, 1.0);

        drive.set(left, right);
    }
}
