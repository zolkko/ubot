//! BLE peripheral role: advertises a custom "robot control" GATT service that the iOS
//! companion app (UbotPad) writes control packets to.
//!
//! No bonding is set up (unencrypted).
//!
//! TODO: add pairing (see `nrf-softdevice`'s `ble_bond_peripheral.rs` example).

use defmt::{info, unwrap};
use embassy_futures::select::{Either, select};
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Sender;
use embassy_time::{Duration, Timer};
use nrf_softdevice::Softdevice;
use nrf_softdevice::ble::advertisement_builder::{
    Flag, LegacyAdvertisementBuilder, LegacyAdvertisementPayload, ServiceList,
};
use nrf_softdevice::ble::{Connection, gatt_server, peripheral};

use crate::gamepad::{GamepadState, PACKET_LEN, parse_packet};
use crate::ultrasonic::UltrasonicSensor;

/// How often the connected client is notified of the ranging sensor's latest reading.
/// Comfortably under the sensor's 25Hz max ranging frequency.
const DISTANCE_NOTIFY_INTERVAL: Duration = Duration::from_millis(100);

/// Custom 128-bit UUIDs, randomly generated for this project. Must match
/// `UbotRemote/UbotRemote/BLEManager.swift` exactly.
pub const ROBOT_SERVICE_UUID: u128 = 0x6f0f6a4e_5a3b_4b8e_9b0a_1f2e3d4c5b6a;

#[nrf_softdevice::gatt_service(uuid = "6f0f6a4e-5a3b-4b8e-9b0a-1f2e3d4c5b6a")]
pub struct RobotService {
    #[characteristic(
        uuid = "6f0f6a4e-5a3b-4b8e-9b0a-1f2e3d4c5b6b",
        write,
        write_without_response
    )]
    pub control: [u8; PACKET_LEN],

    /// Latest ultrasonic ranging reading, in millimeters. Little-endian u16.
    #[characteristic(uuid = "6f0f6a4e-5a3b-4b8e-9b0a-1f2e3d4c5b6c", read, notify)]
    pub distance_mm: u16,
}

#[nrf_softdevice::gatt_server]
pub struct Server {
    pub robot: RobotService,
}

#[embassy_executor::task]
pub async fn softdevice_task(sd: &'static Softdevice) -> ! {
    sd.run().await
}

/// Periodically ranges via `sensor` and notifies `conn` of the result. Read failures
/// (e.g. echo timeout, or an as-yet-unconfigured/disabled CCCD) are dropped silently;
/// the next reading will retry on the next tick.
async fn distance_loop(
    conn: &Connection,
    server: &Server,
    sensor: &mut UltrasonicSensor<'static>,
) -> ! {
    loop {
        if let Ok(mm) = sensor.measure().await {
            let _ = server.robot.distance_mm_notify(conn, &mm);
        }
        Timer::after(DISTANCE_NOTIFY_INTERVAL).await;
    }
}

#[embassy_executor::task]
pub async fn controller_task(
    sd: &'static Softdevice,
    server: &'static Server,
    sender: Sender<'static, ThreadModeRawMutex, GamepadState, 8>,
    mut sensor: UltrasonicSensor<'static>,
) -> ! {
    static ADV_DATA: LegacyAdvertisementPayload = LegacyAdvertisementBuilder::new()
        .flags(&[Flag::GeneralDiscovery, Flag::LE_Only])
        .full_name("Ubot2")
        .build();

    static SCAN_DATA: LegacyAdvertisementPayload = LegacyAdvertisementBuilder::new()
        .services_128(ServiceList::Complete, &[ROBOT_SERVICE_UUID.to_le_bytes()])
        .build();

    loop {
        let config = peripheral::Config::default();
        let adv = peripheral::ConnectableAdvertisement::ScannableUndirected {
            adv_data: &ADV_DATA,
            scan_data: &SCAN_DATA,
        };
        info!("advertising as \"Ubot2\", waiting for the iOS app to connect");
        let conn = unwrap!(peripheral::advertise_connectable(sd, adv, &config).await);
        info!("iOS app connected");

        let gatt_fut = gatt_server::run(&conn, server, |e| match e {
            ServerEvent::Robot(RobotServiceEvent::ControlWrite(packet)) => {
                let state = parse_packet(&packet);
                let _ = sender.try_send(state);
            }
            ServerEvent::Robot(RobotServiceEvent::DistanceMmCccdWrite { notifications }) => {
                info!("distance notifications: {}", notifications);
            }
        });
        let dist_fut = distance_loop(&conn, server, &mut sensor);

        let e = match select(dist_fut, gatt_fut).await {
            Either::First(never) => match never {},
            Either::Second(e) => e,
        };

        info!("iOS app disconnected: {:?}", e);
    }
}
