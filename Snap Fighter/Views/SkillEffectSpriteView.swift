import SpriteKit
import SwiftUI

struct SkillEffectSpriteView: View {
    let scene: SkillEffectScene
    let effect: BattleSkillEffect?

    var body: some View {
        GeometryReader { proxy in
            SpriteView(
                scene: scene,
                options: [.allowsTransparency]
            )
            .onAppear {
                scene.size = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                scene.size = newSize
            }
            .onChange(of: effect) { _, newEffect in
                guard let newEffect else { return }
                scene.play(newEffect, in: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

final class SkillEffectScene: SKScene {
    private enum Layer {
        static let aura: CGFloat = 10
        static let projectile: CGFloat = 20
        static let impact: CGFloat = 30
        static let label: CGFloat = 40
    }

    private static let particleTexture: SKTexture = {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let colors = [
                UIColor.white.withAlphaComponent(1).cgColor,
                UIColor.white.withAlphaComponent(0.62).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.42, 1]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 1,
                endCenter: CGPoint(x: rect.midX, y: rect.midY),
                endRadius: rect.width * 0.5,
                options: []
            )
        }
        return SKTexture(image: image)
    }()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    func play(_ effect: BattleSkillEffect, in viewSize: CGSize) {
        size = viewSize
        removeAllChildren()

        let origin = point(for: effect.actor, in: viewSize)
        let target = targetPoint(for: effect.actor, in: viewSize)
        let style = ElementSkillParticleStyle(element: effect.element, tier: effect.tier)

        addAura(effect: effect, style: style, at: origin)
        addProjectile(effect: effect, style: style, from: origin, to: target)
        addImpact(effect: effect, style: style, at: target)
        addSkillLabel(effect, style: style, near: origin)
    }

    private func point(for actor: BattleActor, in size: CGSize) -> CGPoint {
        switch actor {
        case .player:
            return CGPoint(x: size.width * 0.36, y: size.height * 0.38)
        case .opponent:
            return CGPoint(x: size.width * 0.66, y: size.height * 0.66)
        }
    }

    private func targetPoint(for actor: BattleActor, in size: CGSize) -> CGPoint {
        switch actor {
        case .player:
            return CGPoint(x: size.width * 0.72, y: size.height * 0.70)
        case .opponent:
            return CGPoint(x: size.width * 0.28, y: size.height * 0.32)
        }
    }

    private func addAura(effect: BattleSkillEffect, style: ElementSkillParticleStyle, at point: CGPoint) {
        let emitter = makeEmitter(style: style, mode: .aura)
        emitter.position = point
        emitter.zPosition = Layer.aura
        addChild(emitter)

        let ring = SKShapeNode(circleOfRadius: style.ringRadius)
        ring.position = point
        ring.strokeColor = style.primaryColor.withAlphaComponent(0.95)
        ring.lineWidth = style.ringWidth
        ring.glowWidth = style.ringWidth * 3
        ring.fillColor = .clear
        ring.zPosition = Layer.aura + 1
        addChild(ring)

        let pulse = SKAction.group([
            .scale(to: 1.45, duration: style.auraDuration),
            .fadeOut(withDuration: style.auraDuration)
        ])
        ring.run(.sequence([pulse, .removeFromParent()]))
        emitter.run(.sequence([.wait(forDuration: style.auraDuration), .removeFromParent()]))
    }

    private func addProjectile(
        effect: BattleSkillEffect,
        style: ElementSkillParticleStyle,
        from origin: CGPoint,
        to target: CGPoint
    ) {
        let projectile = SKShapeNode(circleOfRadius: style.projectileRadius)
        projectile.position = origin
        projectile.fillColor = style.primaryColor
        projectile.strokeColor = style.secondaryColor
        projectile.lineWidth = 2
        projectile.glowWidth = style.projectileRadius
        projectile.zPosition = Layer.projectile

        let trail = makeEmitter(style: style, mode: .trail)
        trail.targetNode = self
        projectile.addChild(trail)
        addChild(projectile)

        addElementAccent(for: effect.element, style: style, to: projectile)

        let travel = SKAction.move(to: target, duration: style.travelDuration)
        travel.timingMode = .easeOut
        projectile.run(.sequence([
            .group([travel, .rotate(byAngle: .pi * 2, duration: style.travelDuration)]),
            .removeFromParent()
        ]))
    }

    private func addImpact(effect: BattleSkillEffect, style: ElementSkillParticleStyle, at point: CGPoint) {
        let delay = style.travelDuration * 0.72
        let impact = makeEmitter(style: style, mode: .impact)
        impact.position = point
        impact.zPosition = Layer.impact
        impact.run(.sequence([.wait(forDuration: delay), .run { impact.particleBirthRate = style.impactBirthRate }, .wait(forDuration: style.impactDuration), .removeFromParent()]))
        impact.particleBirthRate = 0
        addChild(impact)

        let wave = SKShapeNode(circleOfRadius: 18)
        wave.position = point
        wave.strokeColor = style.secondaryColor.withAlphaComponent(0.9)
        wave.lineWidth = max(3, style.ringWidth)
        wave.glowWidth = style.ringWidth * 4
        wave.fillColor = .clear
        wave.zPosition = Layer.impact + 1
        wave.alpha = 0
        addChild(wave)

        wave.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeAlpha(to: 0.9, duration: 0.04),
                .scale(to: style.impactScale, duration: style.impactDuration)
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func addSkillLabel(_ effect: BattleSkillEffect, style: ElementSkillParticleStyle, near point: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "\(effect.element.rawValue) \(effect.tier.rawValue)"
        label.fontSize = style.labelFontSize
        label.fontColor = .white
        label.position = CGPoint(x: point.x, y: point.y + style.labelOffset)
        label.zPosition = Layer.label
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.alpha = 0
        addChild(label)

        let glow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        glow.text = label.text
        glow.fontSize = style.labelFontSize
        glow.fontColor = style.primaryColor
        glow.position = .zero
        glow.zPosition = -1
        glow.alpha = 0.75
        label.addChild(glow)

        label.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.08),
                .moveBy(x: 0, y: 10, duration: 0.2)
            ]),
            .wait(forDuration: 0.36),
            .group([
                .fadeOut(withDuration: 0.18),
                .moveBy(x: 0, y: 16, duration: 0.18)
            ]),
            .removeFromParent()
        ]))
    }

    private func addElementAccent(for element: Element, style: ElementSkillParticleStyle, to node: SKNode) {
        switch element {
        case .fire:
            addFlameAccent(style: style, to: node)
        case .water:
            addWaveAccent(style: style, to: node)
        case .grass:
            addLeafAccent(style: style, to: node)
        case .electric:
            addLightningAccent(style: style, to: node)
        case .dark:
            addDarkAccent(style: style, to: node)
        case .normal:
            addStarAccent(style: style, to: node)
        }
    }

    private func addFlameAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let flame = SKShapeNode(path: flamePath(radius: style.projectileRadius * 2.2))
        flame.fillColor = style.secondaryColor.withAlphaComponent(0.85)
        flame.strokeColor = style.primaryColor
        flame.glowWidth = 6
        node.addChild(flame)
    }

    private func addWaveAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -style.projectileRadius * 2.2, y: 0))
        path.addCurve(
            to: CGPoint(x: style.projectileRadius * 2.2, y: 0),
            control1: CGPoint(x: -style.projectileRadius, y: style.projectileRadius * 1.6),
            control2: CGPoint(x: style.projectileRadius, y: -style.projectileRadius * 1.6)
        )
        let wave = SKShapeNode(path: path)
        wave.strokeColor = style.secondaryColor
        wave.lineWidth = 4
        wave.glowWidth = 6
        node.addChild(wave)
    }

    private func addLeafAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let leaf = SKShapeNode(ellipseOf: CGSize(width: style.projectileRadius * 3.2, height: style.projectileRadius * 1.6))
        leaf.fillColor = style.primaryColor.withAlphaComponent(0.8)
        leaf.strokeColor = style.secondaryColor
        leaf.lineWidth = 2
        leaf.glowWidth = 5
        leaf.zRotation = .pi / 4
        node.addChild(leaf)
    }

    private func addLightningAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -style.projectileRadius, y: style.projectileRadius * 2))
        path.addLine(to: CGPoint(x: style.projectileRadius * 0.1, y: style.projectileRadius * 0.2))
        path.addLine(to: CGPoint(x: -style.projectileRadius * 0.15, y: style.projectileRadius * 0.2))
        path.addLine(to: CGPoint(x: style.projectileRadius, y: -style.projectileRadius * 2))
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = style.secondaryColor
        bolt.lineWidth = 5
        bolt.glowWidth = 10
        node.addChild(bolt)
    }

    private func addDarkAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let vortex = SKShapeNode(circleOfRadius: style.projectileRadius * 2.1)
        vortex.strokeColor = style.secondaryColor
        vortex.lineWidth = 4
        vortex.glowWidth = 12
        vortex.fillColor = style.primaryColor.withAlphaComponent(0.34)
        node.addChild(vortex)
    }

    private func addStarAccent(style: ElementSkillParticleStyle, to node: SKNode) {
        let star = SKShapeNode(path: starPath(radius: style.projectileRadius * 2.2))
        star.fillColor = style.primaryColor.withAlphaComponent(0.8)
        star.strokeColor = style.secondaryColor
        star.lineWidth = 2
        star.glowWidth = 7
        node.addChild(star)
    }

    private func makeEmitter(style: ElementSkillParticleStyle, mode: EmitterMode) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.particleTexture
        emitter.particleColor = style.primaryColor
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = style.colorSequence
        emitter.particleAlpha = mode.alpha
        emitter.particleAlphaRange = 0.25
        emitter.particleAlphaSpeed = -mode.alphaSpeed
        emitter.particleScale = mode.scale * style.scaleMultiplier
        emitter.particleScaleRange = mode.scaleRange
        emitter.particleScaleSpeed = -mode.scaleSpeed
        emitter.particleLifetime = mode.lifetime * style.durationMultiplier
        emitter.particleLifetimeRange = mode.lifetimeRange
        emitter.particleBirthRate = mode.birthRate * style.birthRateMultiplier
        emitter.particleSpeed = mode.speed * style.speedMultiplier
        emitter.particleSpeedRange = mode.speedRange
        emitter.emissionAngleRange = mode.angleRange
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = mode.rotationSpeed
        emitter.particleBlendMode = .add
        emitter.numParticlesToEmit = mode.particleLimit(for: style.tier)
        return emitter
    }

    private func flamePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addCurve(to: CGPoint(x: -radius * 0.75, y: -radius * 0.25), control1: CGPoint(x: -radius * 0.7, y: radius * 0.6), control2: CGPoint(x: -radius, y: radius * 0.15))
        path.addCurve(to: CGPoint(x: 0, y: -radius), control1: CGPoint(x: -radius * 0.55, y: -radius * 0.7), control2: CGPoint(x: -radius * 0.2, y: -radius))
        path.addCurve(to: CGPoint(x: radius * 0.7, y: -radius * 0.25), control1: CGPoint(x: radius * 0.35, y: -radius * 0.72), control2: CGPoint(x: radius * 0.88, y: -radius * 0.55))
        path.addCurve(to: CGPoint(x: 0, y: radius), control1: CGPoint(x: radius * 0.42, y: radius * 0.18), control2: CGPoint(x: radius * 0.32, y: radius * 0.58))
        return path
    }

    private func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 10
        for index in 0..<points {
            let currentRadius = index.isMultiple(of: 2) ? radius : radius * 0.42
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(points)) - .pi / 2
            let point = CGPoint(x: cos(angle) * currentRadius, y: sin(angle) * currentRadius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private enum EmitterMode {
    case aura
    case trail
    case impact

    var alpha: CGFloat {
        switch self {
        case .aura: return 0.78
        case .trail: return 0.64
        case .impact: return 0.92
        }
    }

    var alphaSpeed: CGFloat {
        switch self {
        case .aura: return 0.9
        case .trail: return 1.25
        case .impact: return 1.35
        }
    }

    var scale: CGFloat {
        switch self {
        case .aura: return 0.38
        case .trail: return 0.24
        case .impact: return 0.48
        }
    }

    var scaleRange: CGFloat {
        switch self {
        case .aura: return 0.22
        case .trail: return 0.12
        case .impact: return 0.34
        }
    }

    var scaleSpeed: CGFloat {
        switch self {
        case .aura: return 0.18
        case .trail: return 0.26
        case .impact: return 0.32
        }
    }

    var lifetime: CGFloat {
        switch self {
        case .aura: return 0.72
        case .trail: return 0.42
        case .impact: return 0.68
        }
    }

    var lifetimeRange: CGFloat {
        switch self {
        case .aura: return 0.24
        case .trail: return 0.16
        case .impact: return 0.22
        }
    }

    var birthRate: CGFloat {
        switch self {
        case .aura: return 230
        case .trail: return 180
        case .impact: return 420
        }
    }

    var speed: CGFloat {
        switch self {
        case .aura: return 58
        case .trail: return 32
        case .impact: return 180
        }
    }

    var speedRange: CGFloat {
        switch self {
        case .aura: return 42
        case .trail: return 24
        case .impact: return 120
        }
    }

    var angleRange: CGFloat {
        switch self {
        case .aura, .impact: return .pi * 2
        case .trail: return .pi
        }
    }

    var rotationSpeed: CGFloat {
        switch self {
        case .aura: return 1.8
        case .trail: return 2.4
        case .impact: return 3.2
        }
    }

    func particleLimit(for tier: ElementalSkillTier) -> Int {
        switch (self, tier) {
        case (.aura, .low): return 80
        case (.aura, .medium): return 130
        case (.aura, .high): return 190
        case (.trail, .low): return 70
        case (.trail, .medium): return 110
        case (.trail, .high): return 160
        case (.impact, .low): return 95
        case (.impact, .medium): return 160
        case (.impact, .high): return 230
        }
    }
}

private struct ElementSkillParticleStyle {
    let element: Element
    let tier: ElementalSkillTier

    var primaryColor: UIColor {
        switch element {
        case .fire: return UIColor(red: 1, green: 0.18, blue: 0.04, alpha: 1)
        case .water: return UIColor(red: 0.1, green: 0.7, blue: 1, alpha: 1)
        case .grass: return UIColor(red: 0.2, green: 0.92, blue: 0.25, alpha: 1)
        case .electric: return UIColor(red: 1, green: 0.86, blue: 0.05, alpha: 1)
        case .dark: return UIColor(red: 0.42, green: 0.08, blue: 0.78, alpha: 1)
        case .normal: return UIColor(red: 0.82, green: 0.86, blue: 0.92, alpha: 1)
        }
    }

    var secondaryColor: UIColor {
        switch element {
        case .fire: return UIColor(red: 1, green: 0.72, blue: 0.08, alpha: 1)
        case .water: return UIColor(red: 0.62, green: 1, blue: 1, alpha: 1)
        case .grass: return UIColor(red: 0.78, green: 1, blue: 0.24, alpha: 1)
        case .electric: return UIColor.white
        case .dark: return UIColor(red: 0.78, green: 0.24, blue: 1, alpha: 1)
        case .normal: return UIColor.white
        }
    }

    var colorSequence: SKKeyframeSequence {
        SKKeyframeSequence(
            keyframeValues: [
                primaryColor,
                secondaryColor,
                UIColor.white.withAlphaComponent(0.7)
            ],
            times: [0, 0.5, 1]
        )
    }

    var birthRateMultiplier: CGFloat {
        switch tier {
        case .low: return 0.8
        case .medium: return 1.15
        case .high: return 1.55
        }
    }

    var speedMultiplier: CGFloat {
        switch tier {
        case .low: return 0.86
        case .medium: return 1.08
        case .high: return 1.36
        }
    }

    var scaleMultiplier: CGFloat {
        switch tier {
        case .low: return 0.86
        case .medium: return 1.08
        case .high: return 1.32
        }
    }

    var durationMultiplier: CGFloat {
        switch tier {
        case .low: return 0.86
        case .medium: return 1.0
        case .high: return 1.18
        }
    }

    var auraDuration: TimeInterval {
        switch tier {
        case .low: return 0.42
        case .medium: return 0.56
        case .high: return 0.72
        }
    }

    var travelDuration: TimeInterval {
        switch tier {
        case .low: return 0.34
        case .medium: return 0.4
        case .high: return 0.46
        }
    }

    var impactDuration: TimeInterval {
        switch tier {
        case .low: return 0.38
        case .medium: return 0.5
        case .high: return 0.66
        }
    }

    var impactBirthRate: CGFloat {
        460 * birthRateMultiplier
    }

    var projectileRadius: CGFloat {
        switch tier {
        case .low: return 10
        case .medium: return 14
        case .high: return 18
        }
    }

    var ringRadius: CGFloat {
        switch tier {
        case .low: return 34
        case .medium: return 46
        case .high: return 60
        }
    }

    var ringWidth: CGFloat {
        switch tier {
        case .low: return 2.5
        case .medium: return 4
        case .high: return 6
        }
    }

    var impactScale: CGFloat {
        switch tier {
        case .low: return 2.8
        case .medium: return 3.8
        case .high: return 5.0
        }
    }

    var labelFontSize: CGFloat {
        switch tier {
        case .low: return 15
        case .medium: return 18
        case .high: return 22
        }
    }

    var labelOffset: CGFloat {
        switch tier {
        case .low: return 58
        case .medium: return 72
        case .high: return 88
        }
    }
}
