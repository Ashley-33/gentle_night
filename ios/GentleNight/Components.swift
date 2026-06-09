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

    // Same glass-marble layers as the Trends jar: coloured body + fixed gloss.
    var body: some View {
        ZStack {
            Image(uiImage: BeadTex.bodyImage(colors)).resizable().interpolation(.high)
            Image(uiImage: BeadTex.glossImage()).resizable().interpolation(.high)
            if sparkle { GlintCluster(size: size) }
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#5a4628").opacity(0.22), radius: size * 0.07, x: 0, y: size * 0.05)
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
                    .scaleEffect(1.1)
                    .shadow(color: Ramp.accent(metric).opacity(0.45), radius: 6)
            } else {
                // clear glass bubble — see-through, just a rim + highlight
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(showNumber ? 0.06 : 0.12),
                                                  .white.opacity(showNumber ? 0.16 : 0.34)],
                                         center: UnitPoint(x: 0.42, y: 0.4), startRadius: 2, endRadius: 22))
                    .overlay(
                        Circle().stroke(LinearGradient(colors: [.white.opacity(showNumber ? 0.55 : 0.95),
                                                                .white.opacity(0.2)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1)
                    )
                    .overlay(
                        Ellipse().fill(.white.opacity(showNumber ? 0.5 : 0.85))
                            .frame(width: 11, height: 8).offset(x: -7, y: -8).blur(radius: 0.8)
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(showNumber ? 0.18 : 0.06), radius: 2, y: 1)
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

// Self-contained lamp button: reads/writes the shared theme and toggles light/dark.
struct LampThemeButton: View {
    @AppStorage("gentle-night.theme") private var themeRaw = AppTheme.system.rawValue
    @Environment(\.colorScheme) private var scheme

    private var resolvedDark: Bool {
        switch AppTheme(rawValue: themeRaw) ?? .system {
        case .dark: return true
        case .light: return false
        case .system: return scheme == .dark
        }
    }

    var body: some View {
        Button {
            themeRaw = (resolvedDark ? AppTheme.light : AppTheme.dark).rawValue
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            LampToggle(on: resolvedDark)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cute face mascots (sun / leaf / star) drawn with Canvas

struct Mascot: View {
    let metric: Metric
    var size: CGFloat = 40

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let cx = w / 2, cy = h / 2
            switch metric {
            case .mood:     drawSun(ctx, cx, cy, w)
            case .body:     drawLeaf(ctx, cx, cy, w)
            case .tomorrow: drawStar(ctx, cx, cy, w)
            }
        }
        .frame(width: size, height: size)
    }

    private let face = Color(hex: "#6e5638")

    // shared little face: two eyes + smile + rosy cheeks, scaled to radius r about (cx,cy)
    private func drawFace(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        let ew = r * 0.13, eh = r * 0.18, dx = r * 0.34, eyeY = cy - r * 0.04
        for sx in [cx - dx, cx + dx] {
            ctx.fill(Path(ellipseIn: CGRect(x: sx - ew / 2, y: eyeY - eh / 2, width: ew, height: eh)), with: .color(face))
        }
        var smile = Path()
        let sy = cy + r * 0.2
        smile.move(to: CGPoint(x: cx - r * 0.2, y: sy))
        smile.addQuadCurve(to: CGPoint(x: cx + r * 0.2, y: sy), control: CGPoint(x: cx, y: sy + r * 0.3))
        ctx.stroke(smile, with: .color(face), style: StrokeStyle(lineWidth: max(1.1, r * 0.07), lineCap: .round))
        let cheek = Color(hex: "#f2a59a").opacity(0.5), cw = r * 0.17
        for sx in [cx - r * 0.52, cx + r * 0.52] {
            ctx.fill(Path(ellipseIn: CGRect(x: sx - cw / 2, y: cy + r * 0.06, width: cw, height: cw * 0.78)), with: .color(cheek))
        }
    }

    private func drawSun(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        let r = w * 0.29
        let ray = Color(hex: "#f4c24a")
        for i in 0..<8 {
            let ang = Double(i) * .pi / 4
            let dx = CGFloat(cos(ang)), dy = CGFloat(sin(ang))
            let px = -dy, py = dx, pw = r * 0.1
            let r1 = r * 1.16, r2 = r * 1.5
            var p = Path()
            p.move(to: CGPoint(x: cx + dx * r1 + px * pw, y: cy + dy * r1 + py * pw))
            p.addLine(to: CGPoint(x: cx + dx * r2, y: cy + dy * r2))
            p.addLine(to: CGPoint(x: cx + dx * r1 - px * pw, y: cy + dy * r1 - py * pw))
            p.closeSubpath()
            ctx.fill(p, with: .color(ray))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: [Color(hex: "#ffe99c"), Color(hex: "#f6c84e")]),
                                       center: CGPoint(x: cx - r * 0.2, y: cy - r * 0.25), startRadius: 0, endRadius: r * 1.3))
        drawFace(ctx, cx, cy, r)
    }

    private func drawLeaf(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        let r = w * 0.36
        var leaf = Path()
        let top = CGPoint(x: cx, y: cy - r), bot = CGPoint(x: cx, y: cy + r)
        leaf.move(to: top)
        leaf.addQuadCurve(to: bot, control: CGPoint(x: cx + r * 0.82, y: cy))
        leaf.addQuadCurve(to: top, control: CGPoint(x: cx - r * 0.82, y: cy))
        leaf.closeSubpath()
        ctx.fill(leaf, with: .linearGradient(Gradient(colors: [Color(hex: "#aedb8e"), Color(hex: "#7cb85e")]),
                                             startPoint: CGPoint(x: cx - r, y: cy - r), endPoint: CGPoint(x: cx + r, y: cy + r)))
        var vein = Path()
        vein.move(to: CGPoint(x: cx, y: cy + r * 0.72)); vein.addLine(to: CGPoint(x: cx, y: cy - r * 0.6))
        ctx.stroke(vein, with: .color(Color(hex: "#6aa84f").opacity(0.55)), lineWidth: max(0.8, r * 0.05))
        drawFace(ctx, cx, cy + r * 0.05, r * 0.82)
    }

    private func drawStar(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        let R = w * 0.42, ri = R * 0.45
        var star = Path()
        for i in 0..<10 {
            let ang = -Double.pi / 2 + Double(i) * .pi / 5
            let rad = (i % 2 == 0) ? R : ri
            let p = CGPoint(x: cx + CGFloat(cos(ang)) * rad, y: cy + CGFloat(sin(ang)) * rad)
            if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .radialGradient(Gradient(colors: [Color(hex: "#ffe49a"), Color(hex: "#f3c14e")]),
                                             center: CGPoint(x: cx - R * 0.15, y: cy - R * 0.2), startRadius: 0, endRadius: R * 1.1))
        drawFace(ctx, cx, cy + R * 0.06, R * 0.62)
    }
}
