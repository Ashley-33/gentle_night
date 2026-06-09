import SwiftUI
import SpriteKit
import CoreMotion

// MARK: - Device motion → gravity (tilt/shake the phone, beads roll)

final class MotionManager {
    static let shared = MotionManager()
    private let mm = CMMotionManager()
    private(set) var gravity = CGVector(dx: 0, dy: -1)   // default: straight down

    private init() {
        guard mm.isDeviceMotionAvailable else { return }   // simulator → stays default down
        mm.deviceMotionUpdateInterval = 1.0 / 50.0
        mm.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let g = m?.gravity else { return }
            self?.gravity = CGVector(dx: g.x, dy: g.y)
        }
    }
}

// MARK: - Bead textures (glass-marble look, 3 layers)
//
// A real glass marble is read through layering, not one flat sprite:
//   • body  — the coloured glass, rotates with physics (refraction "moves" as it rolls)
//   • gloss — all light/view-dependent shading (specular, rim, terminator); stays
//             SCREEN-FIXED so reflections don't spin with the ball (glass vs plastic)
//   • shadow — soft contact shadow on the ground/cluster, gives weight

enum BeadTex {
    nonisolated(unsafe) private static var bodyImgCache: [String: UIImage] = [:]
    nonisolated(unsafe) private static var glossImgCache: UIImage?
    nonisolated(unsafe) private static var bodyTexCache: [String: SKTexture] = [:]
    nonisolated(unsafe) private static var glossTex: SKTexture?
    nonisolated(unsafe) private static var shadowTex: SKTexture?
    nonisolated(unsafe) private static var sparkleTex: SKTexture?

    // saturate + lift so muted/grey scores read as luminous glass, not mud
    private static func punch(_ ui: UIColor, sat: CGFloat, bri: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return ui }
        return UIColor(hue: h, saturation: min(1, s * sat), brightness: min(1, b * bri), alpha: a)
    }

    private static func colorKey(_ c: BeadColors) -> String {
        func k(_ col: Color) -> String {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(col).getRed(&r, green: &g, blue: &b, alpha: &a)
            return "\(Int(r * 255)).\(Int(g * 255)).\(Int(b * 255))"
        }
        return k(c.light) + "-" + k(c.mid) + "-" + k(c.deep)
    }

    /// Coloured glass body as a UIImage — shared by SpriteKit (Trends) and SwiftUI (Tonight).
    static func bodyImage(_ c: BeadColors) -> UIImage {
        let key = colorKey(c)
        if let i = bodyImgCache[key] { return i }
        let light = punch(UIColor(c.light), sat: 1.10, bri: 1.12)
        let mid   = punch(UIColor(c.mid),   sat: 1.24, bri: 1.10)
        let deep  = punch(UIColor(c.deep),  sat: 1.18, bri: 1.02)
        let S: CGFloat = 104
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let g = ctx.cgContext
            let circle = CGRect(x: 4, y: 4, width: S - 8, height: S - 8)
            g.saveGState()
            g.addEllipse(in: circle); g.clip()
            // base glass: luminous core → saturated mid → colour stays bright to edge (deep only a thin rim)
            let cols = [light.cgColor, mid.cgColor, deep.cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.66, 1]) {
                g.drawRadialGradient(grad,
                    startCenter: CGPoint(x: S * 0.40, y: S * 0.38), startRadius: S * 0.02,
                    endCenter: CGPoint(x: S * 0.5, y: S * 0.5), endRadius: S * 0.56,
                    options: [.drawsAfterEndLocation])
            }
            // transmitted-light caustic — bright pool low in the glass where light focuses through
            let caustic = [light.withAlphaComponent(0.85).cgColor, light.withAlphaComponent(0).cgColor] as CFArray
            if let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: caustic, locations: [0, 1]) {
                g.drawRadialGradient(cg, startCenter: CGPoint(x: S * 0.46, y: S * 0.66), startRadius: 0,
                                     endCenter: CGPoint(x: S * 0.46, y: S * 0.66), endRadius: S * 0.30, options: [])
            }
            g.restoreGState()
            // thin rim — defines the edge on the pale glass jar
            g.setStrokeColor(deep.withAlphaComponent(0.32).cgColor)
            g.setLineWidth(1.0)
            g.strokeEllipse(in: circle.insetBy(dx: 0.6, dy: 0.6))
        }
        bodyImgCache[key] = img; return img
    }

    /// Light/view shading as a UIImage, colour-independent (one shared image).
    static func glossImage() -> UIImage {
        if let i = glossImgCache { return i }
        let S: CGFloat = 104
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let g = ctx.cgContext
            g.saveGState()
            g.addEllipse(in: CGRect(x: 4, y: 4, width: S - 8, height: S - 8)); g.clip()
            // terminator — soft dark only on the far shadow edge (bottom-right), rounds the sphere
            let term = [UIColor.clear.cgColor, UIColor(red: 0.10, green: 0.07, blue: 0.04, alpha: 0.22).cgColor] as CFArray
            if let tg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: term, locations: [0.62, 1]) {
                g.drawRadialGradient(tg, startCenter: CGPoint(x: S * 0.38, y: S * 0.36), startRadius: S * 0.10,
                                     endCenter: CGPoint(x: S * 0.52, y: S * 0.52), endRadius: S * 0.56,
                                     options: [.drawsAfterEndLocation])
            }
            // soft top sheen — kept well inside the rim so it never lights the edge
            let sheen = [UIColor.white.withAlphaComponent(0.36).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sheen, locations: [0, 1]) {
                g.drawRadialGradient(sg, startCenter: CGPoint(x: S * 0.42, y: S * 0.33), startRadius: 0,
                                     endCenter: CGPoint(x: S * 0.43, y: S * 0.35), endRadius: S * 0.28, options: [])
            }
            // gentle transmission glow low INSIDE the glass (interior, not at the edge)
            let glow = [UIColor.white.withAlphaComponent(0.34).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let gw = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow, locations: [0, 1]) {
                g.drawRadialGradient(gw, startCenter: CGPoint(x: S * 0.47, y: S * 0.64), startRadius: 0,
                                     endCenter: CGPoint(x: S * 0.47, y: S * 0.64), endRadius: S * 0.17, options: [])
            }
            // soft inner transmission arc, pulled well inside the edge → no white rim
            let rim = UIBezierPath(arcCenter: CGPoint(x: S / 2, y: S / 2), radius: (S - 24) / 2,
                                   startAngle: .pi * 0.22, endAngle: .pi * 0.78, clockwise: true)
            rim.lineWidth = 3.0; rim.lineCapStyle = .round
            UIColor.white.withAlphaComponent(0.30).setStroke(); rim.stroke()
            g.restoreGState()
            // sharp specular hot-spot (top-left), the signature glass glint
            g.setFillColor(UIColor.white.withAlphaComponent(0.98).cgColor)
            g.fillEllipse(in: CGRect(x: S * 0.28, y: S * 0.20, width: S * 0.13, height: S * 0.105))
            // ultra-bright pinpoint core of the glint
            g.setFillColor(UIColor.white.cgColor)
            g.fillEllipse(in: CGRect(x: S * 0.31, y: S * 0.225, width: S * 0.05, height: S * 0.045))
            // secondary tiny glint
            g.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            g.fillEllipse(in: CGRect(x: S * 0.45, y: S * 0.33, width: S * 0.045, height: S * 0.045))
        }
        glossImgCache = img; return img
    }

    /// Coloured glass body (SpriteKit texture for the physics scene).
    static func body(_ metric: Metric, _ score: Int) -> SKTexture {
        let key = "\(metric.rawValue)-\(score)"
        if let t = bodyTexCache[key] { return t }
        let t = SKTexture(image: bodyImage(Ramp.colors(metric, score)))
        bodyTexCache[key] = t; return t
    }

    /// Light/view shading (SpriteKit texture, kept screen-fixed).
    static func gloss() -> SKTexture {
        if let t = glossTex { return t }
        let t = SKTexture(image: glossImage()); glossTex = t; return t
    }

    /// Soft contact shadow (flattened, sits under a bead).
    static func shadow() -> SKTexture {
        if let t = shadowTex { return t }
        let S: CGFloat = 100
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let g = ctx.cgContext
            let cols = [UIColor(red: 0.20, green: 0.14, blue: 0.05, alpha: 0.40).cgColor,
                        UIColor(red: 0.20, green: 0.14, blue: 0.05, alpha: 0).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                g.drawRadialGradient(grad, startCenter: CGPoint(x: S / 2, y: S / 2), startRadius: 0,
                                     endCenter: CGPoint(x: S / 2, y: S / 2), endRadius: S / 2, options: [])
            }
        }
        let t = SKTexture(image: img); shadowTex = t; return t
    }

    /// Twinkle for the best score.
    static func sparkle() -> SKTexture {
        if let t = sparkleTex { return t }
        let S: CGFloat = 44
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let g = ctx.cgContext
            g.setFillColor(UIColor.white.cgColor)
            let cx = S / 2, cy = S / 2, a: CGFloat = S * 0.46, b: CGFloat = S * 0.14
            var pts = [CGPoint]()
            for i in 0..<8 {
                let ang = CGFloat(i) * .pi / 4
                let r = (i % 2 == 0) ? a : b
                pts.append(CGPoint(x: cx + cos(ang) * r, y: cy + sin(ang) * r))
            }
            g.beginPath(); g.addLines(between: pts); g.closePath(); g.fillPath()
        }
        let t = SKTexture(image: img); sparkleTex = t; return t
    }
}

// MARK: - Physics scene (gravity, collisions, rolling glass marbles in a jar)

final class JarScene: SKScene {
    struct Spec { let r: CGFloat; let metric: Metric; let score: Int }
    private var configured = false
    // bead = rotating body + screen-fixed gloss child + tracked contact shadow
    private var beads: [(body: SKSpriteNode, gloss: SKSpriteNode, shadow: SKSpriteNode, r: CGFloat)] = []

    func configure(size: CGSize, specs: [Spec]) {
        guard size.width > 1, size.height > 1 else { return }
        self.size = size
        scaleMode = .resizeFill
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -9)
        // jar boundary (rounded box)
        let inset: CGFloat = 3
        let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        let radius = min(20, rect.width * 0.22)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let wall = SKPhysicsBody(edgeLoopFrom: path)
        wall.friction = 0.5; wall.restitution = 0.08
        physicsBody = wall
        // beads
        removeAllChildren(); beads.removeAll()
        var rng = SystemRandomNumberGenerator()
        for (i, s) in specs.enumerated() {
            // contact shadow (drawn under everything)
            let shadow = SKSpriteNode(texture: BeadTex.shadow())
            shadow.size = CGSize(width: s.r * 2.15, height: s.r * 1.25)
            shadow.zPosition = 0
            addChild(shadow)
            // glass body — carries the physics, rotates
            let body = SKSpriteNode(texture: BeadTex.body(s.metric, s.score))
            body.size = CGSize(width: s.r * 2, height: s.r * 2)
            body.zPosition = 1
            let x = CGFloat.random(in: s.r...max(s.r, size.width - s.r), using: &rng)
            body.position = CGPoint(x: x, y: size.height - s.r - CGFloat(i) * 1.5)   // pour from the top
            let pb = SKPhysicsBody(circleOfRadius: s.r * 0.95)
            pb.restitution = 0.14; pb.friction = 0.5; pb.linearDamping = 0.5
            pb.angularDamping = 0.55; pb.allowsRotation = true
            body.physicsBody = pb
            addChild(body)
            // gloss — child of body so it follows position; counter-rotated each frame to stay screen-fixed
            let gloss = SKSpriteNode(texture: BeadTex.gloss())
            gloss.size = body.size
            gloss.zPosition = 1
            body.addChild(gloss)
            if s.score >= 5 {
                let sp = SKSpriteNode(texture: BeadTex.sparkle())
                sp.size = CGSize(width: s.r * 0.7, height: s.r * 0.7)
                sp.position = CGPoint(x: s.r * 0.36, y: s.r * 0.34)
                sp.blendMode = .add
                gloss.addChild(sp)   // rides the screen-fixed gloss
            }
            beads.append((body, gloss, shadow, s.r))
        }
        configured = true
    }

    override func update(_ currentTime: TimeInterval) {
        guard configured else { return }
        let g = MotionManager.shared.gravity
        physicsWorld.gravity = CGVector(dx: g.dx * 9, dy: g.dy * 9)
        // keep gloss reflections pointing at the (screen-fixed) light, drop shadows under beads
        for b in beads {
            b.gloss.zRotation = -b.body.zRotation
            b.shadow.position = CGPoint(x: b.body.position.x, y: b.body.position.y - b.r * 0.6)
        }
    }
}

// MARK: - SwiftUI wrapper for the physics beads

struct PhysicsBeads: View {
    let metric: Metric
    let scores: [Int]
    let size: CGSize
    @State private var scene = JarScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .onAppear { scene.isPaused = false; scene.configure(size: size, specs: specs()) }
            .onDisappear { scene.isPaused = true }
            .onChange(of: scores) { _ in scene.configure(size: size, specs: specs()) }
            .onChange(of: size) { _ in scene.configure(size: size, specs: specs()) }
    }

    private func specs() -> [JarScene.Spec] {
        var used = scores
        if used.count > 70 {
            let step = Double(used.count) / 70
            used = (0..<70).map { used[Int(Double($0) * step)] }
        }
        let n = used.count
        guard n > 0, size.width > 1 else { return [] }
        let base = size.width * 0.16
        let r = min(max(base * sqrt(CGFloat(16) / CGFloat(n)), size.width * 0.058), size.width * 0.17)
        return used.map { score in
            JarScene.Spec(r: r * CGFloat.random(in: 0.9...1.12), metric: metric, score: score)
        }
    }
}

// MARK: - Jar (realistic glass + physics beads + cork)

struct JarView: View {
    let metric: Metric
    let scores: [Int]
    @Environment(\.colorScheme) private var scheme

    private var jarShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 34,
                               bottomTrailingRadius: 34, topTrailingRadius: 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            cork
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    // back wall — near-clear glass, faint cool tint only at the edges (thickness)
                    jarShape.fill(backWall)
                    PhysicsBeads(metric: metric, scores: scores, size: geo.size)  // tumbling beads
                        .clipShape(jarShape)

                    // inner glass reflections — kept inside the jar
                    ZStack {
                        // light pooling off the glass floor
                        Ellipse()
                            .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.16 : 0.5), .clear],
                                                 startPoint: .bottom, endPoint: .top))
                            .frame(width: w * 0.8, height: h * 0.13)
                            .position(x: w * 0.52, y: h * 0.95).blur(radius: 3)
                        // primary specular streak (left), crisp glass reflection
                        RoundedRectangle(cornerRadius: w * 0.05)
                            .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.55 : 0.95),
                                                          .white.opacity(scheme == .dark ? 0.06 : 0.18)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: w * 0.07, height: h * 0.6).blur(radius: 1.3)
                            .position(x: w * 0.23, y: h * 0.42)
                        // secondary thin streak
                        Capsule().fill(.white.opacity(scheme == .dark ? 0.32 : 0.62))
                            .frame(width: w * 0.02, height: h * 0.52).blur(radius: 0.8)
                            .position(x: w * 0.33, y: h * 0.44)
                        // far (right) wall — bright thin edge
                        Capsule().fill(.white.opacity(scheme == .dark ? 0.28 : 0.5))
                            .frame(width: w * 0.018, height: h * 0.56).blur(radius: 1.0)
                            .position(x: w * 0.865, y: h * 0.46)
                    }
                    .clipShape(jarShape).allowsHitTesting(false)

                    // mouth rim — glass thickness, brighter where light hits (top-left)
                    Ellipse()
                        .stroke(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.55 : 0.9),
                                                        rimColor.opacity(0.5)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.7)
                        .frame(width: w * 0.72, height: h * 0.052)
                        .position(x: w * 0.5, y: h * 0.035).allowsHitTesting(false)
                    Ellipse()                                   // soft inner-mouth shadow under the rim
                        .fill(LinearGradient(colors: [glassEdge.opacity(0.20), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.64, height: h * 0.06)
                        .position(x: w * 0.5, y: h * 0.06).allowsHitTesting(false)

                    jarShape.stroke(outlineGradient, lineWidth: 1.8).allowsHitTesting(false)
                }
            }
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.0 : 0.10), radius: 10, y: 8)
    }

    private var cork: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: "#ecd3a6"), Color(hex: "#cba775")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 20)
            Capsule().fill(Color(hex: "#e6c89a")).frame(height: 7).padding(.horizontal, 8).offset(y: -3)
        }
        .frame(width: 64)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
        .zIndex(2)
    }

    // colors — clear glass reads cool/neutral, not warm frosted
    private var glassEdge: Color {
        scheme == .dark ? Color(hex: "#9aa6d0") : Color(hex: "#aebab4")
    }
    private var backWall: LinearGradient {
        LinearGradient(stops: [
            .init(color: glassEdge.opacity(scheme == .dark ? 0.34 : 0.42), location: 0),
            .init(color: glassEdge.opacity(0.10), location: 0.12),
            .init(color: .clear, location: 0.32),
            .init(color: .clear, location: 0.68),
            .init(color: glassEdge.opacity(0.12), location: 0.88),
            .init(color: glassEdge.opacity(scheme == .dark ? 0.36 : 0.48), location: 1)],
            startPoint: .leading, endPoint: .trailing)
    }
    private var outlineGradient: LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(hex: "#cfd8f5").opacity(0.8), Color(hex: "#8e9bcb").opacity(0.5)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [Color(hex: "#f3f5f2"), Color(hex: "#a7b1ac")],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var rimColor: Color {
        scheme == .dark ? Color(hex: "#c9d2f0").opacity(0.7) : Color(hex: "#cdd3ce")
    }
}
