import SwiftUI
import MetalKit
import GameController
import TouchController


struct TouchPadView: UIViewRepresentable {
    var manager: TouchControllerManager
    var isEnabled: Bool

    func makeCoordinator() -> Renderer {
        Renderer(manager: manager)
    }

    func makeUIView(context: Context) -> TouchPadMTKView {
        let mtkView = TouchPadMTKView()
        mtkView.renderer = context.coordinator
        mtkView.delegate = context.coordinator
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm

        // transparency settings
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.5)

        // The underlying CAMetalLayer also needs to know it's not opaque
        mtkView.layer.isOpaque = false

        mtkView.isMultipleTouchEnabled = true

        return mtkView
    }

    func updateUIView(_ uiView: TouchPadMTKView, context: Context) {
        context.coordinator.setEnabled(isEnabled)
    }
}

final class TouchPadMTKView: MTKView {
    weak var renderer: Renderer?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = renderer?.touchController?.handleTouchBegan(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = renderer?.touchController?.handleTouchMoved(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = renderer?.touchController?.handleTouchEnded(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = renderer?.touchController?.handleTouchEnded(at: touch.location(in: self), index: touch.hash)
        }
    }
}

class Renderer: NSObject, MTKViewDelegate {
    private let manager: TouchControllerManager
    fileprivate var touchController: TCTouchController?

    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var isEnabled = true

    init(manager: TouchControllerManager) {
        self.manager = manager
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        guard let touchController else { return }
        if enabled {
            touchController.connect()
        } else {
            touchController.disconnect()
        }
    }

    private func setupTouchController(for view: MTKView) {
        let descriptor = TCTouchControllerDescriptor(mtkView: view)
        let controller = TCTouchController(descriptor: descriptor)

        let stickDescriptor = makeLeftStick(for: controller)
        _ = controller.addThumbstick(descriptor: stickDescriptor)

        Task { @MainActor [weak self] in
            self?.manager.attachedVirtualController(controller.controller)
        }

        controller.controller.extendedGamepad?.valueChangedHandler = { [weak manager] gamepad, _ in
            Task { @MainActor in
                manager?.update(
                    lx: gamepad.leftThumbstick.xAxis.value,
                    ly: gamepad.leftThumbstick.yAxis.value
                )
            }
        }

        touchController = controller
        if isEnabled {
            controller.connect()
        }
    }
    
    private func makeLeftStick(for controller: TCTouchController) -> TCThumbstickDescriptor {
        let stickDescriptor = TCThumbstickDescriptor()
        stickDescriptor.size = CGSize(width: 140, height: 140)
        stickDescriptor.stickSize = CGSize(width: 64, height: 64)
        stickDescriptor.hidesWhenNotPressed = false
        stickDescriptor.label = TCControlLabel(name: "LeftStick", role: .directionPad)

        stickDescriptor.anchor = .bottomLeft
        stickDescriptor.anchorCoordinateSystem = .absolute
        stickDescriptor.offset = CGPoint(x: 24, y: -24)
        stickDescriptor.backgroundContents = TCControlContents.thumbstickStickBackgroundContents(
            size: stickDescriptor.size,
            controller: controller
        )
        stickDescriptor.stickContents = TCControlContents.thumbstickStickContents(
            size: stickDescriptor.stickSize,
            controller: controller
        )

        return stickDescriptor
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if touchController == nil {
            setupTouchController(for: view)
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        AppLogger.app.info("Draw \(Foundation.Date.now.timeIntervalSince1970)")

        touchController?.render(using: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        TouchPadView(manager: TouchControllerManager(), isEnabled: true)
    }
}
