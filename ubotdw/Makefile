export PATH := $(HOME)/.cargo/bin:$(PATH)

XCFRAMEWORK_NAME := ubotdw
XCFRAMEWORK := build/$(XCFRAMEWORK_NAME).xcframework

define MODULEMAP
module $(XCFRAMEWORK_NAME) {
  header "$(XCFRAMEWORK_NAME).h"
  export *
}
endef
export MODULEMAP

#- Name: ubotdw_SpeedometerHandle
#  SwiftName: Speedometer
#  SwiftImportAs: owned
#  SwiftRetainOp: speedometer_free
#  SwiftReleaseOp: speedometer_free
#Functions:
#- Name: speedometer_draw
#  SwiftReturnOwnership: retained
#  SwiftName: Speedometer.draw(self:value:)

define APINOTES
Name: $(XCFRAMEWORK_NAME)
Tags:
endef
export APINOTES


.PHONY: xcframework

xcframework: $(XCFRAMEWORK)


$(XCFRAMEWORK): ./src/lib.rs ./Cargo.toml ./cbindgen.toml ./rust-toolchain.toml
	cargo build --release --target aarch64-apple-ios
	cargo build --release --target aarch64-apple-ios-sim
	rm -rf $(XCFRAMEWORK)
	mkdir -p build
	xcodebuild -create-xcframework \
		-library target/aarch64-apple-ios/release/lib$(XCFRAMEWORK_NAME).a -headers include \
		-library target/aarch64-apple-ios-sim/release/lib$(XCFRAMEWORK_NAME).a -headers include \
		-output $(XCFRAMEWORK)
	@echo "$$MODULEMAP" > $(XCFRAMEWORK)/ios-arm64/Headers/module.modulemap
	@echo "$$MODULEMAP" > $(XCFRAMEWORK)/ios-arm64-simulator/Headers/module.modulemap
	@echo "$$APINOTES" > $(XCFRAMEWORK)/ios-arm64/Headers/$(XCFRAMEWORK_NAME).apinotes
	@echo "$$APINOTES" > $(XCFRAMEWORK)/ios-arm64-simulator/Headers/$(XCFRAMEWORK_NAME).apinotes


iface: $(XCFRAMEWORK)
	xcrun swift-synthesize-interface -I $(XCFRAMEWORK)/ios-arm64/Headers \
		-module-name $(XCFRAMEWORK_NAME) \
		-target arm64-apple-ios \
		-sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk


.PHONY: check

check:
	@cargo check


.PHONY: clean

clean:
	cargo clean
	rm -rf build
