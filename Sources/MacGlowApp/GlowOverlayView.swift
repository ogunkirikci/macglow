import AppKit

struct TopGlowLayout {
    let leftWidth: CGFloat
    let rightWidth: CGFloat

    init(screen: NSScreen) {
        leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
    }

    var hasNotch: Bool {
        leftWidth > 0 && rightWidth > 0
    }
}

@MainActor
protocol GlowRendering: AnyObject {
    var level: Double { get set }
    var glowAppearance: GlowAppearance { get set }
}

final class GlowOverlayView: NSView {
    var level: Double = 0.25 {
        didSet { renderer.level = level }
    }

    var glowAppearance: GlowAppearance {
        didSet { renderer.glowAppearance = glowAppearance }
    }

    private let renderer: NSView & GlowRendering

    init(frame frameRect: NSRect, glowAppearance: GlowAppearance, topGlowLayout: TopGlowLayout) {
        self.glowAppearance = glowAppearance
        if let metalRenderer = MetalGlowView(
            frame: NSRect(origin: .zero, size: frameRect.size),
            glowAppearance: glowAppearance,
            topGlowLayout: topGlowLayout
        ) {
            renderer = metalRenderer
#if DEBUG
            print("MacGlow renderer: Metal")
#endif
        } else {
            renderer = AppKitGlowView(
                frame: NSRect(origin: .zero, size: frameRect.size),
                glowAppearance: glowAppearance,
                topGlowLayout: topGlowLayout
            )
#if DEBUG
            print("MacGlow renderer: AppKit fallback")
#endif
        }
        super.init(frame: frameRect)
        wantsLayer = true
        renderer.autoresizingMask = [.width, .height]
        addSubview(renderer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }
}

private final class AppKitGlowView: NSView, GlowRendering {
    var level: Double = 0.25 {
        didSet { needsDisplay = true }
    }

    var glowAppearance: GlowAppearance {
        didSet { needsDisplay = true }
    }

    private let topGlowLayout: TopGlowLayout

    init(frame frameRect: NSRect, glowAppearance: GlowAppearance, topGlowLayout: TopGlowLayout) {
        self.glowAppearance = glowAppearance
        self.topGlowLayout = topGlowLayout
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let strength = glowAppearance.intensity * level
        guard strength > 0.001 else { return }

        let spread = glowAppearance.spread * (1.15 + strength * 0.45)
        let clear = NSColor.clear

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 18, yRadius: 18).addClip()
        drawGradient(
            colors: [glowAppearance.leftColor.withAlphaComponent(0.92 * strength),
                     glowAppearance.leftColor.withAlphaComponent(0.30 * strength), clear],
            locations: [0, 0.24, 1],
            in: NSRect(x: 0, y: 0, width: spread, height: bounds.height),
            angle: 0
        )
        drawGradient(
            colors: [clear, glowAppearance.rightColor.withAlphaComponent(0.26 * strength),
                     glowAppearance.rightColor.withAlphaComponent(0.92 * strength)],
            locations: [0, 0.76, 1],
            in: NSRect(x: bounds.maxX - spread, y: 0, width: spread, height: bounds.height),
            angle: 0
        )
        drawGradient(
            colors: [glowAppearance.bottomColor.withAlphaComponent(0.96 * strength),
                     glowAppearance.bottomColor.withAlphaComponent(0.34 * strength), clear],
            locations: [0, 0.22, 1],
            in: NSRect(x: 0, y: 0, width: bounds.width, height: spread),
            angle: 90
        )
        drawTopGradient(clear: clear, strength: strength, spread: spread)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawTopGradient(clear: NSColor, strength: Double, spread: CGFloat) {
        let colors = [clear, glowAppearance.topColor.withAlphaComponent(0.22 * strength),
                      glowAppearance.topColor.withAlphaComponent(0.92 * strength)]
        let fullRect = NSRect(x: 0, y: bounds.maxY - spread, width: bounds.width, height: spread)

        guard glowAppearance.notchCompatibility, topGlowLayout.hasNotch else {
            drawGradient(colors: colors, locations: [0, 0.78, 1], in: fullRect, angle: 90)
            return
        }

        let leftWidth = min(topGlowLayout.leftWidth, bounds.width)
        let rightWidth = min(topGlowLayout.rightWidth, bounds.width - leftWidth)
        drawGradient(
            colors: colors,
            locations: [0, 0.78, 1],
            in: NSRect(x: 0, y: bounds.maxY - spread, width: leftWidth, height: spread),
            angle: 90
        )
        drawGradient(
            colors: colors,
            locations: [0, 0.78, 1],
            in: NSRect(x: bounds.maxX - rightWidth, y: bounds.maxY - spread, width: rightWidth, height: spread),
            angle: 90
        )
    }

    private func drawGradient(colors: [NSColor], locations: [CGFloat], in rect: NSRect, angle: CGFloat) {
        guard rect.width > 0, rect.height > 0,
              let gradient = NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB) else {
            return
        }
        gradient.draw(in: rect, angle: angle)
    }
}
