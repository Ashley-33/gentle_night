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

// MARK: - Bead textures (cached per metric+score)

enum BeadTex {
    nonisolated(unsafe) static var cache: [String: SKTexture] = [:]

    static func texture(_ metric: Metric, _ score: Int) -> SKTexture {
        let key = "\(metric.rawValue)-\(score)"
        if let t = cache[key] { return t }
        let c = Ramp.colors(metric, score)
        let S: CGFloat = 88
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let g = ctx.cgContext
            g.addEllipse(in: CGRect(x: 3, y: 3, width: S - 6, height: S - 6)); g.clip()
            let cols = [UIColor(c.light).cgColor, UIColor(c.mid).cgColor, UIColor(c.deep).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.72, 1]) {
                g.drawRadialGradient(grad,
                    startCenter: CGPoint(x: S * 0.38, y: S * 0.36), startRadius: 0,
                    endCenter: CGPoint(x: S * 0.5, y: S * 0.5), endRadius: S * 0.62, options: [])
            }
            // glossy highlight
            g.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            g.fillEllipse(in: CGRect(x: S * 0.24, y: S * 0.18, width: S * 0.22, height: S * 0.17))
            // tiny sparkle for the best score
            if score >= 5 {
                g.setFillColor(UIColor(white: 1, alpha: 0.95).cgColor)
                let cx = S * 0.66, cy = S * 0.34, a: CGFloat = 7
                var star = [CGPoint]()
                for i in 0..<8 {
                    let ang = CGFloat(i) * .pi / 4
                    let rad = (i % 2 == 0) ? a : a * 0.4
                    star.append(CGPoint(x: cx + cos(ang) * rad, y: cy + sin(ang) * rad))
                }
                g.beginPath(); g.addLines(between: star); g.closePath(); g.fillPath()
            }
        }
        let t = SKTexture(image: img)
        cache[key] = t
        return t
    }
}

// MARK: - Physics scene (gravity, collisions, rolling beads in a jar boundary)

final class JarScene: SKScene {
    struct Spec { let r: CGFloat; let tex: SKTexture }
    private var configured = false

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
        removeAllChildren()
        var rng = SystemRandomNumberGenerator()
        for (i, s) in specs.enumerated() {
            let node = SKSpriteNode(texture: s.tex)
            node.size = CGSize(width: s.r * 2, height: s.r * 2)
            let x = CGFloat.random(in: s.r...max(s.r, size.width - s.r), using: &rng)
            node.position = CGPoint(x: x, y: size.height - s.r - CGFloat(i) * 1.5)   // pour from the top
            let body = SKPhysicsBody(circleOfRadius: s.r * 0.95)
            body.restitution = 0.12
            body.friction = 0.5
            body.linearDamping = 0.55
            body.angularDamping = 0.6
            body.allowsRotation = true
            node.physicsBody = body
            addChild(node)
        }
        configured = true
    }

    override func update(_ currentTime: TimeInterval) {
        guard configured else { return }
        let g = MotionManager.shared.gravity
        physicsWorld.gravity = CGVector(dx: g.dx * 9, dy: g.dy * 9)
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
            JarScene.Spec(r: r * CGFloat.random(in: 0.9...1.12), tex: BeadTex.texture(metric, score))
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
                    jarShape.fill(bodyGradient)                                   // back glass
                    PhysicsBeads(metric: metric, scores: scores, size: geo.size)  // tumbling beads
                        .clipShape(jarShape)
                    // front-glass highlights
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.5 : 0.9), .white.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.085, height: h * 0.6).blur(radius: 2.5)
                        .position(x: w * 0.22, y: h * 0.36).allowsHitTesting(false)
                    Capsule()
                        .fill(.white.opacity(scheme == .dark ? 0.22 : 0.55))
                        .frame(width: w * 0.028, height: h * 0.48).blur(radius: 1.4)
                        .position(x: w * 0.865, y: h * 0.42).allowsHitTesting(false)
                    Ellipse().stroke(rimColor, lineWidth: 1.4)
                        .frame(width: w * 0.7, height: h * 0.05)
                        .position(x: w * 0.5, y: h * 0.035).allowsHitTesting(false)
                    jarShape.stroke(outlineGradient, lineWidth: 1.7).allowsHitTesting(false)
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

    // colors
    private var bodyGradient: LinearGradient {
        scheme == .dark
        ? LinearGradient(stops: [
            .init(color: Color(hex: "#aebbe8").opacity(0.30), location: 0),
            .init(color: Color(hex: "#8a98c8").opacity(0.12), location: 0.14),
            .init(color: .clear, location: 0.42),
            .init(color: .clear, location: 0.60),
            .init(color: Color(hex: "#8a98c8").opacity(0.12), location: 0.86),
            .init(color: Color(hex: "#b6c2ef").opacity(0.32), location: 1)],
            startPoint: .leading, endPoint: .trailing)
        : LinearGradient(stops: [
            .init(color: Color(hex: "#d4c8ae"), location: 0),
            .init(color: Color(hex: "#e7ddc7").opacity(0.55), location: 0.13),
            .init(color: .clear, location: 0.34),
            .init(color: .clear, location: 0.66),
            .init(color: Color(hex: "#e7ddc7").opacity(0.55), location: 0.87),
            .init(color: Color(hex: "#cdc1a5"), location: 1)],
            startPoint: .leading, endPoint: .trailing)
    }
    private var outlineGradient: LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(hex: "#cfd8f5").opacity(0.75), Color(hex: "#8e9bcb").opacity(0.5)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [Color(hex: "#ede4d1"), Color(hex: "#bcaf90")],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var rimColor: Color {
        scheme == .dark ? Color(hex: "#c9d2f0").opacity(0.6) : Color(hex: "#d6caaa")
    }
}
