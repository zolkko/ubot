//! DFRobot "Gravity: Ultrasonic Sensor 2.0" ("D" URM09, SEN0388) driver (URM09)[https://www.dfrobot.com/product-2172.html].

use embassy_nrf::Peri;
use embassy_nrf::gpio::{Flex, OutputDrive, Pin as GpioPin, Pull};
use embassy_time::{Duration, Instant, Timer, WithTimeout};

/// "a high-level about tens of microseconds" to trigger ranging.
const TRIGGER_PULSE: Duration = Duration::from_micros(20);

/// rated range is 2..500cm (~29ms round trip at 343 m/s);
const ECHO_TIMEOUT: Duration = Duration::from_millis(60);

/// mm per microsecond of echo pulse width: speed of sound (343 m/s = 0.343 mm/us),
/// halved because the pulse covers the round trip (there and back).
const MM_PER_US: f32 = 343.0 / 2000.0;

/// Sensor's rated effective range, per its datasheet.
pub const MIN_DISTANCE_MM: u16 = 20;
pub const MAX_DISTANCE_MM: u16 = 5000;

#[derive(Debug, defmt::Format)]
pub enum UltrasonicError {
    Timeout,
}

impl core::fmt::Display for UltrasonicError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            UltrasonicError::Timeout => write!(f, "timeout waiting for echo pulse"),
        }
    }
}

impl core::error::Error for UltrasonicError {
}

pub struct UltrasonicSensor<'d> {
    sig: Flex<'d>,
}

impl<'d> UltrasonicSensor<'d> {
    pub fn new(sig: Peri<'d, impl GpioPin>) -> Self {
        let mut sig = Flex::new(sig);
        sig.set_as_input(Pull::None);
        Self { sig }
    }

    /// Generate an output pulse, then switch the pin to input and measure the echo pulse width.
    /// Returns a distance in millimeters.
    pub async fn measure(&mut self) -> Result<u16, UltrasonicError> {
        self.sig.set_as_output(OutputDrive::Standard);
        self.sig.set_high();
        Timer::after(TRIGGER_PULSE).await;
        self.sig.set_low();
        self.sig.set_as_input(Pull::None);

        self.sig.wait_for_high().with_timeout(ECHO_TIMEOUT)
            .await
            .map_err(|_| UltrasonicError::Timeout)?;
        let start = Instant::now();

        self.sig.wait_for_low().with_timeout(ECHO_TIMEOUT)
            .await
            .map_err(|_| UltrasonicError::Timeout)?;
        let pulse_us = (Instant::now() - start).as_micros() as f32;

        let mm = (pulse_us * MM_PER_US) as u16;
        Ok(mm.clamp(MIN_DISTANCE_MM, MAX_DISTANCE_MM))
    }
}
