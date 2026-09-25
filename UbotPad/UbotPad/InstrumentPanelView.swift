import MetalKit
import UIKit
import SwiftUI
import os


struct InstrumentPanelView: UIViewRepresentable {
    func makeUIView(context: Context) -> InstrumentPanelMetalView {
        return InstrumentPanelMetalView()
    }

    func updateUIView(_ uiView: InstrumentPanelMetalView, context: Context) {
    }
}

final class InstrumentPanelMetalView: MTKView {

    private var speedometer_ptr: SpeedometerPtr!;

    init() {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("failed to create Metal device")
        }

        super.init(frame: .zero, device: metalDevice)

        self.framebufferOnly = false
        self.colorPixelFormat = .bgra8Unorm

        // transparency settings
        self.isOpaque = false
        self.layer.isOpaque = false

        self.backgroundColor = .clear
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        self.isMultipleTouchEnabled = false

        do {
            try self.speedometer_ptr = SpeedometerPtr(view: self)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        do {
            try self.speedometer_ptr = SpeedometerPtr(view: self)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    override func draw(_ rect: CGRect) {
        self.drawSpeedometers(left: 80, right: 40)
    }

    fileprivate func drawSpeedometers(left: UInt64, right: UInt64) {
        do {
            try self.speedometer_ptr.draw(left: left, right: right)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

final class SpeedometerPtr {

    nonisolated(unsafe) let raw: OpaquePointer

    init(view: UIView) throws {
        var error: NSError?
        let r = speedometer_new(view, &error)
        if let error {
            throw error
        }

        self.raw = r!
    }
    
    func draw(left: UInt64, right: UInt64) throws {
        var error: NSError?
        speedometer_draw(self.raw, left, right, &error)
        
        if let error {
            throw error
        }
    }

    deinit {
        speedometer_free(self.raw)
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        InstrumentPanelView()
    }
}
