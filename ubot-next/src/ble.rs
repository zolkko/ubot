//! BLE peripheral role: advertises a custom "robot control" GATT service that the iOS
//! companion app (UbotPad) writes control packets to.
//!
//! No bonding is set up (unencrypted).
//!
//! TODO: add pairing (see `nrf-softdevice`'s `ble_bond_peripheral.rs` example).

use defmt::{info, unwrap};
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Sender;
use nrf_softdevice::Softdevice;
use nrf_softdevice::ble::advertisement_builder::{
    Flag, LegacyAdvertisementBuilder, LegacyAdvertisementPayload, ServiceList,
};
use nrf_softdevice::ble::{gatt_server, peripheral};

use crate::gamepad::{GamepadState, PACKET_LEN, parse_packet};

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
}

#[nrf_softdevice::gatt_server]
pub struct Server {
    pub robot: RobotService,
}

#[embassy_executor::task]
pub async fn softdevice_task(sd: &'static Softdevice) -> ! {
    sd.run().await
}

#[embassy_executor::task]
pub async fn controller_task(
    sd: &'static Softdevice,
    server: &'static Server,
    sender: Sender<'static, ThreadModeRawMutex, GamepadState, 8>,
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
        let conn = peripheral::advertise_connectable(sd, adv, &config)
            .await
            .unwrap(); // TODO: fixme
        info!("iOS app connected");

        let e = gatt_server::run(&conn, server, |e| match e {
            ServerEvent::Robot(RobotServiceEvent::ControlWrite(packet)) => {
                let state = parse_packet(&packet);
                let _ = sender.try_send(state);
            }
        })
        .await;

        // info!("iOS app disconnected: {:?}", e.to_string());
        info!("iOS app disconnected");
    }
}
