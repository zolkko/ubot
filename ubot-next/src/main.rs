#![no_std]
#![no_main]

mod ble;
mod gamepad;
mod motors;
mod robot;

use core::mem;

use defmt::{info, unwrap};
use defmt_rtt as _;
use panic_probe as _;

use embassy_executor::Spawner;
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Channel;
use nrf_softdevice::{Softdevice, raw};

use crate::ble::Server;
use crate::gamepad::GamepadState;
use crate::motors::TrackDrive;

static GAMEPAD_CHANNEL: Channel<ThreadModeRawMutex, GamepadState, 8> = Channel::new();

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    let mut config = embassy_nrf::config::Config::default();
    config.gpiote_interrupt_priority = embassy_nrf::interrupt::Priority::P2;
    config.time_interrupt_priority = embassy_nrf::interrupt::Priority::P2;

    let p = embassy_nrf::init(config);

    info!("ubot-next boot");

    let sd_config = nrf_softdevice::Config {
        clock: Some(raw::nrf_clock_lf_cfg_t {
            source: raw::NRF_CLOCK_LF_SRC_RC as u8,
            rc_ctiv: 16,
            rc_temp_ctiv: 2,
            accuracy: raw::NRF_CLOCK_LF_ACCURACY_500_PPM as u8,
        }),
        conn_gap: Some(raw::ble_gap_conn_cfg_t {
            conn_count: 1,
            event_length: 24,
        }),
        conn_gatt: Some(raw::ble_gatt_conn_cfg_t { att_mtu: 64 }),
        gatts_attr_tab_size: Some(raw::ble_gatts_cfg_attr_tab_size_t {
            attr_tab_size: raw::BLE_GATTS_ATTR_TAB_SIZE_DEFAULT,
        }),
        gap_role_count: Some(raw::ble_gap_cfg_role_count_t {
            adv_set_count: 1,
            periph_role_count: 1,
            central_role_count: 0,
            central_sec_count: 0,
            _bitfield_1: raw::ble_gap_cfg_role_count_t::new_bitfield_1(0),
        }),
        gap_device_name: Some(raw::ble_gap_cfg_device_name_t {
            p_value: b"ubot2" as *const u8 as _,
            current_len: 5,
            max_len: 5,
            write_perm: unsafe { mem::zeroed() },
            _bitfield_1: raw::ble_gap_cfg_device_name_t::new_bitfield_1(
                raw::BLE_GATTS_VLOC_STACK as u8,
            ),
        }),
        ..Default::default()
    };

    let sd = Softdevice::enable(&sd_config);
    let server = unwrap!(Server::new(sd));
    spawner.spawn(unwrap!(ble::softdevice_task(sd)));

    let drive = TrackDrive::new(
        p.PWM0,
        p.P0_06,
        p.P0_13,
        motors::output(p.P0_03),
        motors::output(p.P0_04),
        motors::output(p.P0_05),
        motors::output(p.P0_07),
        motors::output(p.P0_08),
    );

    let server: &'static Server = {
        use static_cell::StaticCell;
        static SERVER: StaticCell<Server> = StaticCell::new();
        SERVER.init(server)
    };

    spawner.spawn(unwrap!(ble::controller_task(
        sd,
        server,
        GAMEPAD_CHANNEL.sender()
    )));
    spawner.spawn(unwrap!(robot_task(GAMEPAD_CHANNEL.receiver(), drive)));
}

#[embassy_executor::task]
async fn robot_task(
    receiver: embassy_sync::channel::Receiver<'static, ThreadModeRawMutex, GamepadState, 8>,
    drive: TrackDrive<'static>,
) {
    robot::run(receiver, drive).await;
}
