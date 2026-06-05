import SwiftUI

// MARK: - Seeded RNG (stable bead layout per render)

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// gravity drop-and-rest packing: returns a centre point per bead
func packDrop(width: CGFloat, height: CGFloat, radii: [CGFloat], seed: UInt64) -> [CGPoint] {
    var rng = SeededRNG(seed: seed)
    var placed: [(p: CGPoint, r: CGFloat)] = []
    for r in radii {
        var best: CGPoint?
        let span = max(0.001, width - 2 * r)
        for _ in 0..<28 {
            let x = r + CGFloat.random(in: 0...span, using: &rng)
            var y = height - r
            for q in placed {
                let dx = x - q.p.x, sum = r + q.r
                if abs(dx) < sum {
                    let dy = (sum * sum - dx * dx).squareRoot()
                    y = min(y, q.p.y - dy)
                }
            }
            if best == nil || y > best!.y { best = CGPoint(x: x, y: y) }
        }
        placed.append((best!, r))
    }
    return placed.map { $0.p }
}

// MARK: - Crescent moon

struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        let r2 = r * 0.92, off = r * 0.5
        p.addEllipse(in: CGRect(x: c.x - r2 + off, y: c.y - r2 - off * 0.45, width: 2 * r2, height: 2 * r2))
        return p
    }
}

struct MoonView: View {
    var glow = false
    var body: some View {
        Crescent()
            .fill(LinearGradient(colors: [Color(hex: "#fff3c6"), Color(hex: "#f1c04a")],
                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                  style: FillStyle(eoFill: true))
            .rotationEffect(.degrees(-18))
            .shadow(color: Color(hex: "#f5cf6c").opacity(glow ? 0.8 : 0.45), radius: glow ? 14 : 8)
    }
}

// MARK: - Twinkle sparkle

struct Twinkle: View {
    let size: CGFloat
    let delay: Double
    @State private var on = false
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(.white)
            .shadow(color: Color(hex: "#ffe9a0").opacity(0.95), radius: 3)
            .opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.35)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}

struct GlintCluster: View {
    let size: CGFloat   // bead diameter
    var body: some View {
        ZStack {
            Twinkle(size: size * 0.5, delay: 0).offset(x: -size * 0.16, y: -size * 0.18)
            Twinkle(size: size * 0.3, delay: 0.6).offset(x: size * 0.14, y: size * 0.06)
            Twinkle(size: size * 0.24, delay: 1.1).offset(x: -size * 0.02, y: size * 0.17)
        }
    }
}

// MARK: - Bead

struct BeadView: View {
    let colors: BeadColors
    let size: CGFloat
    var sparkle = false

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [colors.light, colors.mid, colors.deep],
                                 center: UnitPoint(x: 0.4, y: 0.32),
                                 startRadius: 0, endRadius: size * 0.62))
            .overlay(
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.9), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.2))
                    .frame(width: size * 0.42, height: size * 0.34)
                    .offset(x: -size * 0.14, y: -size * 0.2)
            )
            .frame(width: size, height: size)
            .shadow(color: Color(hex: "#5a4628").opacity(0.22), radius: size * 0.07, x: 0, y: size * 0.05)
            .overlay { if sparkle { GlintCluster(size: size) } }
    }
}

// MARK: - Score orb (Tonight)

struct OrbView: View {
    let metric: Metric
    let value: Int
    let selected: Bool
    let showNumber: Bool

    var body: some View {
        ZStack {
            if selected {
                BeadView(colors: Ramp.colors(metric, value), size: 44, sparkle: value >= 5)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5).frame(width: 44, height: 44))
                    .scaleEffect(1.08)
            } else {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: "#efe9e0")],
                                         center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: 26))
                    .overlay(
                        Ellipse().fill(.white.opacity(0.8))
                            .frame(width: 14, height: 11).offset(x: -8, y: -9).blur(radius: 1)
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
            }
            if showNumber {
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? .white : Palette.txtFaint)
            }
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }
}

// MARK: - Cozy lamp + plant theme toggle (lit = dark/night, off = light/day)

struct LampToggle: View {
    let on: Bool

    var body: some View {
        Canvas { ctx, size in
            let W = size.width, H = size.height
            let lampCX = W * 0.74
            let potCX  = W * 0.34

            // warm glow behind the lamp
            let glow = Color(hex: "#ffdf95")
            let halo = Path(ellipseIn: CGRect(x: lampCX - 26, y: 2, width: 52, height: 52))
            ctx.fill(halo, with: .radialGradient(
                Gradient(colors: [glow.opacity(on ? 0.9 : 0.35), .clear]),
                center: CGPoint(x: lampCX, y: 28), startRadius: 0, endRadius: on ? 28 : 18))

            // shelf
            let shelf = Path(roundedRect: CGRect(x: W * 0.20, y: H - 8, width: W * 0.80, height: 7), cornerRadius: 3)
            ctx.fill(shelf, with: .linearGradient(
                Gradient(colors: [Color(hex: "#e8c89b"), Color(hex: "#d0aa76")]),
                startPoint: CGPoint(x: 0, y: H - 8), endPoint: CGPoint(x: 0, y: H - 1)))

            // ---- dome lamp ----
            // base
            let base = Path(roundedRect: CGRect(x: lampCX - 15, y: H - 13, width: 30, height: 8), cornerRadius: 3.5)
            ctx.fill(base, with: .linearGradient(
                Gradient(colors: [Color(hex: "#ecbf72"), Color(hex: "#caa052")]),
                startPoint: CGPoint(x: 0, y: H - 13), endPoint: CGPoint(x: 0, y: H - 5)))
            // shade (rounded dome)
            let dw: CGFloat = 26, dh: CGFloat = 28
            let dx = lampCX - dw / 2, dyB = H - 11
            var dome = Path()
            dome.move(to: CGPoint(x: dx, y: dyB))
            dome.addLine(to: CGPoint(x: dx, y: dyB - dh * 0.5))
            dome.addQuadCurve(to: CGPoint(x: dx + dw / 2, y: dyB - dh), control: CGPoint(x: dx, y: dyB - dh))
            dome.addQuadCurve(to: CGPoint(x: dx + dw, y: dyB - dh * 0.5), control: CGPoint(x: dx + dw, y: dyB - dh))
            dome.addLine(to: CGPoint(x: dx + dw, y: dyB))
            dome.closeSubpath()
            ctx.fill(dome, with: .radialGradient(
                Gradient(colors: [Color(hex: "#fff7df"), Color(hex: on ? "#ffe49a" : "#efddb6")]),
                center: CGPoint(x: dx + dw / 2, y: dyB - dh * 0.45), startRadius: 1, endRadius: dw))
            // soft top highlight
            let hi = Path(ellipseIn: CGRect(x: dx + dw * 0.24, y: dyB - dh * 0.92, width: dw * 0.3, height: dh * 0.3))
            ctx.fill(hi, with: .color(.white.opacity(0.6)))

            // ---- potted plant ----
            // pot
            var pot = Path()
            pot.move(to: CGPoint(x: potCX - 11, y: H - 21))
            pot.addLine(to: CGPoint(x: potCX + 11, y: H - 21))
            pot.addLine(to: CGPoint(x: potCX + 8, y: H - 8))
            pot.addLine(to: CGPoint(x: potCX - 8, y: H - 8))
            pot.closeSubpath()
            ctx.fill(pot, with: .linearGradient(
                Gradient(colors: [Color(hex: "#f6efe4"), Color(hex: "#e7dcc9")]),
                startPoint: CGPoint(x: 0, y: H - 21), endPoint: CGPoint(x: 0, y: H - 8)))
            // pot rim
            let rim = Path(roundedRect: CGRect(x: potCX - 12.5, y: H - 24, width: 25, height: 5.5), cornerRadius: 2.5)
            ctx.fill(rim, with: .color(Color(hex: "#efe6d6")))
            // leaves
            let greens = [Color(hex: "#92c877"), Color(hex: "#79b35d"), Color(hex: "#a9d98c"), Color(hex: "#6aa84f")]
            let stem = CGPoint(x: potCX, y: H - 23)
            let leaves: [(x: CGFloat, y: CGFloat, rot: Double, len: CGFloat, c: Int)] = [
                (0, -20, 0, 18, 1), (-8, -15, -34, 15, 0), (8, -16, 34, 15, 2),
                (-12, -8, -62, 12, 3), (12, -9, 62, 12, 1), (-4, -11, -14, 14, 2), (5, -12, 16, 14, 0),
            ]
            for lf in leaves {
                ctx.drawLayer { l in
                    l.translateBy(x: stem.x + lf.x, y: stem.y + lf.y)
                    l.rotate(by: .degrees(lf.rot))
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: 0, y: lf.len / 2))
                    leaf.addQuadCurve(to: CGPoint(x: 0, y: -lf.len / 2), control: CGPoint(x: lf.len * 0.38, y: 0))
                    leaf.addQuadCurve(to: CGPoint(x: 0, y: lf.len / 2), control: CGPoint(x: -lf.len * 0.38, y: 0))
                    l.fill(leaf, with: .color(greens[lf.c]))
                }
            }
        }
        .frame(width: 96, height: 60)
        .contentShape(Rectangle())
    }
}
