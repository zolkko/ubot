//! Wiring (nRF52840 -> Motor driver H-bridge):
//!   P0.03 -> STBY
//!   P0.04 -> AIN1   P0.05 -> AIN2   P0.06 (PWM0 ch0) -> PWMA  (left track)
//!   P0.07 -> BIN1   P0.08 -> BIN2   P0.13 (PWM0 ch1) -> PWMB  (right track)
//! Motor supply (VM) comes from the robot's battery, not the nRF52840's 3V3 rail.

use embassy_nrf::Peri;
use embassy_nrf::gpio::{Level, Output, OutputDrive, Pin as GpioPin};
use embassy_nrf::peripherals::PWM0;
use embassy_nrf::pwm::{DutyCycle, Prescaler, SimpleConfig, SimplePwm};

const MAX_DUTY: u16 = 1000;

// const LEFT_CHANNEL: usize = 0;
// const RIGHT_CHANNEL: usize = 1;

pub struct TrackDrive<'d> {
    pwm: SimplePwm<'d>,
    stby: Output<'d>,
    left_in1: Output<'d>,
    left_in2: Output<'d>,
    right_in1: Output<'d>,
    right_in2: Output<'d>,
}

impl<'d> TrackDrive<'d> {
    pub fn new(
        pwm0: Peri<'d, PWM0>,
        pwma_pin: Peri<'d, impl GpioPin>,
        pwmb_pin: Peri<'d, impl GpioPin>,
        stby: Output<'d>,
        left_in1: Output<'d>,
        left_in2: Output<'d>,
        right_in1: Output<'d>,
        right_in2: Output<'d>,
    ) -> Self {
        let config = SimpleConfig::default();
        let mut pwm = SimplePwm::new_2ch(pwm0, pwma_pin, pwmb_pin, &config);
        pwm.set_prescaler(Prescaler::Div16);
        pwm.set_max_duty(MAX_DUTY);
        pwm.set_duty(0, DutyCycle::normal(0));
        pwm.set_duty(1, DutyCycle::normal(0));

        Self {
            pwm,
            stby,
            left_in1,
            left_in2,
            right_in1,
            right_in2,
        }
    }

    pub fn enable(&mut self) {
        self.stby.set_high();
    }

    pub fn disable(&mut self) {
        self.stby.set_low();
        self.pwm.set_duty(0, DutyCycle::normal(0));
        self.pwm.set_duty(1, DutyCycle::normal(0));
    }

    /// `left`/`right` in [-1.0, 1.0]: sign is direction, magnitude is speed.
    pub fn set(&mut self, left: f32, right: f32) {
        Self::apply(
            &mut self.pwm,
            0,
            &mut self.left_in1,
            &mut self.left_in2,
            left,
        );
        Self::apply(
            &mut self.pwm,
            1,
            &mut self.right_in1,
            &mut self.right_in2,
            right,
        );
    }

    fn apply(
        pwm: &mut SimplePwm<'d>,
        channel: usize,
        in1: &mut Output<'d>,
        in2: &mut Output<'d>,
        value: f32,
    ) {
        let clamped = value.clamp(-1.0, 1.0);
        match clamped.partial_cmp(&0.0) {
            Some(core::cmp::Ordering::Greater) => {
                in1.set_high();
                in2.set_low();
            }
            Some(core::cmp::Ordering::Less) => {
                in1.set_low();
                in2.set_high();
            }
            _ => {
                in1.set_low();
                in2.set_low();
            }
        }
        let duty = (clamped.abs() * MAX_DUTY as f32) as u16;
        pwm.set_duty(channel, DutyCycle::normal(duty));
    }
}

pub fn output<'d>(pin: Peri<'d, impl GpioPin>) -> Output<'d> {
    Output::new(pin, Level::Low, OutputDrive::Standard)
}
