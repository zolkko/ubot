final class SpeedometerWrapper {

    private let speedometer_ptr: OpaquePointer;

    init(view: UIView) {
        self.speedometer_ptr = speedometer_new(view)
    }

    func draw(speed: UInt64) {
        speedometer_draw(self.speedometer_ptr, speed)
    }

    deinit {
        speedometer_free(self.speedometer_ptr)
    }
}
