import AppKit
import MetalKit
import simd

private struct MetalGlowUniforms {
    var geometry: SIMD4<Float>
    var notch: SIMD4<Float>
    var topColor: SIMD4<Float>
    var rightColor: SIMD4<Float>
    var bottomColor: SIMD4<Float>
    var leftColor: SIMD4<Float>
}

final class MetalGlowView: MTKView, GlowRendering, MTKViewDelegate {
    override var isOpaque: Bool { false }

    var level: Double = 0.25 {
        didSet { needsDisplay = true }
    }

    var glowAppearance: GlowAppearance {
        didSet { needsDisplay = true }
    }

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let topGlowLayout: TopGlowLayout

    init?(
        frame frameRect: NSRect,
        glowAppearance: GlowAppearance,
        topGlowLayout: TopGlowLayout
    ) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { return nil }

        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            guard let vertex = library.makeFunction(name: "glowVertex"),
                  let fragment = library.makeFunction(name: "glowFragment") else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        self.commandQueue = commandQueue
        self.glowAppearance = glowAppearance
        self.topGlowLayout = topGlowLayout
        super.init(frame: frameRect, device: device)
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        layer?.isOpaque = false
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = true
        preferredFramesPerSecond = 30
        delegate = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let passDescriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        let strength = Float(glowAppearance.intensity * min(max(level, 0), 1))
        let spread = Float(glowAppearance.spread * (1.15 + Double(strength) * 0.45))
        var uniforms = MetalGlowUniforms(
            geometry: SIMD4(Float(bounds.width), Float(bounds.height), spread, strength),
            notch: SIMD4(
                glowAppearance.notchCompatibility && topGlowLayout.hasNotch ? 1 : 0,
                Float(topGlowLayout.leftWidth),
                Float(topGlowLayout.rightWidth),
                0
            ),
            topColor: glowAppearance.topColor.rgbaVector,
            rightColor: glowAppearance.rightColor.rgbaVector,
            bottomColor: glowAppearance.bottomColor.rgbaVector,
            leftColor: glowAppearance.leftColor.rgbaVector
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MetalGlowUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut { float4 position [[position]]; float2 uv; };
    struct GlowUniforms {
        float4 geometry; float4 notch; float4 topColor;
        float4 rightColor; float4 bottomColor; float4 leftColor;
    };

    vertex VertexOut glowVertex(uint vertexID [[vertex_id]]) {
        const float2 positions[6] = {
            float2(-1, -1), float2(1, -1), float2(-1, 1),
            float2(-1, 1), float2(1, -1), float2(1, 1)
        };
        VertexOut output;
        output.position = float4(positions[vertexID], 0, 1);
        output.uv = positions[vertexID] * 0.5 + 0.5;
        return output;
    }

    fragment float4 glowFragment(VertexOut input [[stage_in]], constant GlowUniforms &u [[buffer(0)]]) {
        float2 size = u.geometry.xy;
        float spread = max(u.geometry.z, 1.0);
        float strength = u.geometry.w;
        if (strength < 0.001) return float4(0);

        float2 pixel = input.uv * size;
        float left = pow(clamp(1.0 - pixel.x / spread, 0.0, 1.0), 2.1);
        float right = pow(clamp(1.0 - (size.x - pixel.x) / spread, 0.0, 1.0), 2.1);
        float bottom = pow(clamp(1.0 - pixel.y / spread, 0.0, 1.0), 2.1);
        float top = pow(clamp(1.0 - (size.y - pixel.y) / spread, 0.0, 1.0), 2.1);
        if (u.notch.x > 0.5 && pixel.x > u.notch.y && pixel.x < size.x - u.notch.z) top = 0.0;

        float total = left + right + bottom + top;
        if (total < 0.0001) return float4(0);
        float3 color = (u.leftColor.rgb * left + u.rightColor.rgb * right +
                        u.bottomColor.rgb * bottom + u.topColor.rgb * top) / total;
        float alpha = clamp(max(max(left, right), max(bottom, top)) * strength * 0.92, 0.0, 1.0);
        return float4(color, alpha);
    }
    """
}

private extension NSColor {
    var rgbaVector: SIMD4<Float> {
        guard let color = usingColorSpace(.sRGB) else { return SIMD4(1, 1, 1, 1) }
        return SIMD4(
            Float(color.redComponent), Float(color.greenComponent),
            Float(color.blueComponent), Float(color.alphaComponent)
        )
    }
}
