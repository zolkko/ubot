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

    private weak var manager: GameControllerManager?
    
    fileprivate var speedometer: SpeedometerWrapper?

    init?(renderer: Renderer, manager: GameControllerManager) {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        self.manager = manager

        super.init(frame: .zero, device: metalDevice)

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

        manager.touchController = self.touchController
        
        self.speedometer = SpeedometerWrapper(view: self)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.speedometer = SpeedometerWrapper(view: self)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        manager?.userDidTouchScreen()
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

struct CircleUniforms {
    var resolution: SIMD2<Float>
}

class Renderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var circlePipelineState: MTLRenderPipelineState!

    override init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()
        super.init()

        self.circlePipelineState = Renderer.makeCirclePipelineState(device: device)
    }

    private static func makeCirclePipelineState(device: MTLDevice) -> MTLRenderPipelineState? {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "circle_vertex"),
              let fragmentFunction = library.makeFunction(name: "circle_fragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
//        guard let drawable = view.currentDrawable,
//              let descriptor = view.currentRenderPassDescriptor,
//              let commandBuffer = commandQueue.makeCommandBuffer(),
//              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
//        else { return }

        /*
        if let circlePipelineState {
            var uniforms = CircleUniforms(resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)))
            encoder.setRenderPipelineState(circlePipelineState)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CircleUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        (view as! TouchPadMTKView).touchController.render(using: encoder)
         */

//        encoder.endEncoding()
//        commandBuffer.present(drawable)
//        commandBuffer.commit()

        (view as! TouchPadMTKView).speedometer?.draw(speed: 50)
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        TouchPadView(manager: GameControllerManager())
    }
}
