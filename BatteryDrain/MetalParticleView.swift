import MetalKit
import SwiftUI

struct MetalParticleView: UIViewRepresentable {
    let isRunning: Bool
    let preferredFrameRate: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.01, green: 0.01, blue: 0.014, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = true
        view.isPaused = !isRunning
        view.preferredFramesPerSecond = preferredFrameRate
        view.delegate = context.coordinator

        context.coordinator.configure(device: view.device)

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.isPaused = !isRunning
        uiView.preferredFramesPerSecond = preferredFrameRate
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private let particleCount = 24_000
        private let startTime = CACurrentMediaTime()
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?

        func configure(device: MTLDevice?) {
            guard let device, pipelineState == nil else { return }

            commandQueue = device.makeCommandQueue()

            let source = """
            #include <metal_stdlib>
            using namespace metal;

            struct VertexOut {
                float4 position [[position]];
                float4 color;
            };

            float hash(float n) {
                return fract(sin(n) * 43758.5453123);
            }

            vertex VertexOut particleVertex(uint vertexID [[vertex_id]], constant float &time [[buffer(0)]]) {
                uint particleID = vertexID / 3;
                uint cornerID = vertexID % 3;
                float id = float(particleID);
                float seedA = hash(id * 12.9898);
                float seedB = hash(id * 78.233);
                float seedC = hash(id * 37.719);
                float radius = 0.15 + seedA * 0.86;
                float angle = seedB * 6.2831853 + time * (0.25 + seedC * 1.6);
                float wave = sin(time * 1.9 + id * 0.017) * 0.08;
                float size = 0.004 + seedC * 0.005;

                float2 position = float2(cos(angle), sin(angle)) * (radius + wave);
                position.x += sin(time * 0.73 + id * 0.031) * 0.16;
                position.y += cos(time * 0.61 + id * 0.027) * 0.12;

                float2 corners[3] = {
                    float2(0.0, size),
                    float2(-size * 0.866, -size * 0.5),
                    float2(size * 0.866, -size * 0.5)
                };

                VertexOut out;
                out.position = float4(position + corners[cornerID], 0, 1);
                out.color = float4(0.2 + seedA * 0.8, 0.75 + seedB * 0.2, 0.65 + seedC * 0.32, 0.9);
                return out;
            }

            fragment half4 particleFragment(VertexOut in [[stage_in]]) {
                return half4(in.color);
            }
            """

            do {
                let library = try device.makeLibrary(source: source, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "particleVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "particleFragment")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                descriptor.colorAttachments[0].isBlendingEnabled = true
                descriptor.colorAttachments[0].rgbBlendOperation = .add
                descriptor.colorAttachments[0].alphaBlendOperation = .add
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                pipelineState = nil
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }

        func draw(in view: MTKView) {
            guard
                let drawable = view.currentDrawable,
                let renderPassDescriptor = view.currentRenderPassDescriptor,
                let commandQueue,
                let pipelineState,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                return
            }

            var time = Float(CACurrentMediaTime() - startTime)
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBytes(&time, length: MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: particleCount * 3)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
