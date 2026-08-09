import SwiftUI
import MetalKit
import GameController
import TouchController


struct TouchPadView: UIViewRepresentable {
    @State var manager: GameControllerManager

    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeUIView(context: Context) -> TouchPadMTKView {
        guard let view = TouchPadMTKView(renderer: context.coordinator, manager: self.manager) else {
            fatalError("failed to create TouchPadMTKView")
        }
        return view
    }

    func updateUIView(_ uiView: TouchPadMTKView, context: Context) {
    }
}

final class TouchPadMTKView: MTKView {

    // Metal View holds a reference to TouchController
    // as its life time is bound and makes no sense without the view.
    fileprivate var touchController: TCTouchController!
    
    weak var manager: GameControllerManager?
    
    init?(renderer: Renderer, manager: GameControllerManager) {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        
        super.init(frame: .zero, device: metalDevice)

        self.manager = manager
        self.delegate = renderer

        self.framebufferOnly = false
        self.colorPixelFormat = .bgra8Unorm

        // transparency settings
        self.isOpaque = false
        self.backgroundColor = .clear
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.5)

        // The underlying CAMetalLayer also needs to know it's not opaque
        self.layer.isOpaque = false

        self.isMultipleTouchEnabled = true

        self.touchController = TouchPadMTKView.makeTouchController(for: self)

        self.manager?.touchController = self.touchController
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = touchController.handleTouchBegan(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = touchController.handleTouchMoved(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = touchController.handleTouchEnded(at: touch.location(in: self), index: touch.hash)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = touchController.handleTouchEnded(at: touch.location(in: self), index: touch.hash)
        }
    }
    
    private static func makeTouchController(for view: MTKView) -> TCTouchController {
        let descriptor = TCTouchControllerDescriptor(mtkView: view)
        let controller = TCTouchController(descriptor: descriptor)

        let stickDescriptor = makeLeftStick(for: controller)
        _ = controller.addThumbstick(descriptor: stickDescriptor)

//        Task { @MainActor [weak self] in
//            self?.manager?.touchController = controller
//        }

// TODO: move into GameControllerManager ...
//        controller.controller.extendedGamepad?.valueChangedHandler = { [weak manager] gamepad, _ in
//            Task { @MainActor in
//                manager?.update(
//                    lx: gamepad.leftThumbstick.xAxis.value,
//                    ly: gamepad.leftThumbstick.yAxis.value
//                )
//            }
//        }

//        controller.connect()
//        touchController.disconnect()
        return controller
    }
    
    private static func makeLeftStick(for controller: TCTouchController) -> TCThumbstickDescriptor {
        let stickDescriptor = TCThumbstickDescriptor()
        stickDescriptor.size = CGSize(width: 140, height: 140)
        stickDescriptor.stickSize = CGSize(width: 64, height: 64)
        stickDescriptor.hidesWhenNotPressed = false
        stickDescriptor.label = TCControlLabel.leftThumbstick

        stickDescriptor.anchor = .bottomLeft // .topLeft
        stickDescriptor.anchorCoordinateSystem = .relative // .absolute
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
}

class Renderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!

    override init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        (view as! TouchPadMTKView).touchController.render(using: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        TouchPadView(manager: GameControllerManager())
    }
}
