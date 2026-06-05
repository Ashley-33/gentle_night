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

// MARK: - Desk lamp theme toggle (lit = dark/night, off = light/day)

struct LampToggle: View {
    let on: Bool
    var body: some View {
        ZStack {
            if on {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#ffe6a0").opacity(0.9), .clear],
                                         center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 64, height: 64)
                    .offset(x: 2, y: 6)
            }
            Image(systemName: "lamp.desk.fill")
                .font(.system(size: 30))
                .foregroundStyle(on
                    ? LinearGradient(colors: [Color(hex: "#ffd96a"), Color(hex: "#e6b144")],
                                     startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(hex: "#bcae96"), Color(hex: "#9b8d77")],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: on ? Color(hex: "#ffd76a").opacity(0.85) : .clear, radius: 8)
        }
        .frame(width: 54, height: 54)
        .contentShape(Rectangle())
    }
}
