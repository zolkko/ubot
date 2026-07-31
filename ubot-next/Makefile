SOFTDEVICE_HEX := s140_nrf52_7.2.0_softdevice.hex

.PHONY: sd_flash
sd_flash:
	@test -f $(SOFTDEVICE_HEX) || { \
		echo "error: $(SOFTDEVICE_HEX) not found in $(CURDIR)"; \
		echo "download it from https://www.nordicsemi.com/Products/Development-software/nRF5-SDK/Download and place it here"; \
		exit 1; \
	}
	probe-rs erase --chip nRF52840_xxAA --allow-erase-all
	probe-rs download --verify --binary-format hex --chip nRF52840_xxAA $(SOFTDEVICE_HEX)


.PHONY: run
run:
	@cargo run
