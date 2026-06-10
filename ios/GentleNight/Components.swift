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
    var tint: Color = .white
    @State private var on = false
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(tint)
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
        .frame(width: 106, height: 66)
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
        .shadow(color: glowColor.opacity(0.55), radius: size * 0.13)   // soft glow halo
    }

    private var glowColor: Color {
        switch metric {
        case .mood: Color(hex: "#f6cf6a")
        case .body: Color(hex: "#9bd17e")
        case .tomorrow: Color(hex: "#c3a7ea")
        }
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
        let r = w * 0.32   // chubby body
        let ray = Color(hex: "#f4c24a")
        for i in 0..<8 {   // short stubby rounded rays
            let ang = Double(i) * .pi / 4
            let dx = CGFloat(cos(ang)), dy = CGFloat(sin(ang))
            var p = Path()
            p.move(to: CGPoint(x: cx + dx * r * 1.04, y: cy + dy * r * 1.04))
            p.addLine(to: CGPoint(x: cx + dx * r * 1.3, y: cy + dy * r * 1.3))
            ctx.stroke(p, with: .color(ray), style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: [Color(hex: "#ffe99c"), Color(hex: "#f6c84e")]),
                                       center: CGPoint(x: cx - r * 0.2, y: cy - r * 0.25), startRadius: 0, endRadius: r * 1.3))
        drawFace(ctx, cx, cy, r)
    }

    private func drawLeaf(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        let r = w * 0.4   // plump, almost-round leaf
        var leaf = Path()
        let top = CGPoint(x: cx, y: cy - r * 0.74), bot = CGPoint(x: cx, y: cy + r * 0.74)
        leaf.move(to: top)
        leaf.addQuadCurve(to: bot, control: CGPoint(x: cx + r * 1.28, y: cy))
        leaf.addQuadCurve(to: top, control: CGPoint(x: cx - r * 1.28, y: cy))
        leaf.closeSubpath()
        ctx.fill(leaf, with: .linearGradient(Gradient(colors: [Color(hex: "#aedb8e"), Color(hex: "#7cb85e")]),
                                             startPoint: CGPoint(x: cx - r, y: cy - r), endPoint: CGPoint(x: cx + r, y: cy + r)))
        var vein = Path()
        vein.move(to: CGPoint(x: cx, y: cy + r * 0.55)); vein.addLine(to: CGPoint(x: cx, y: cy - r * 0.45))
        ctx.stroke(vein, with: .color(Color(hex: "#6aa84f").opacity(0.5)), lineWidth: max(0.8, r * 0.05))
        drawFace(ctx, cx, cy + r * 0.05, r * 0.66)
    }

    private func drawStar(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        let R = w * 0.33, ri = R * 0.54   // fat star; thick round stroke puffs the points
        var star = Path()
        for i in 0..<10 {
            let ang = -Double.pi / 2 + Double(i) * .pi / 5
            let rad = (i % 2 == 0) ? R : ri
            let p = CGPoint(x: cx + CGFloat(cos(ang)) * rad, y: cy + CGFloat(sin(ang)) * rad)
            if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        let shade = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [Color(hex: "#ffe49a"), Color(hex: "#f3c14e")]),
            center: CGPoint(x: cx - R * 0.12, y: cy - R * 0.16), startRadius: 0, endRadius: R * 1.1)
        ctx.fill(star, with: shade)
        ctx.stroke(star, with: shade, style: StrokeStyle(lineWidth: R * 0.32, lineCap: .round, lineJoin: .round))
        drawFace(ctx, cx, cy + R * 0.04, R * 0.56)
    }
}

// MARK: - Ambient backdrop (soft clouds / cozy glow + scattered sparkles)

struct AmbientBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    // sparkles in the upper area: (xFrac, yFrac, size, delay)
    private let spots: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.09, 0.13, 9, 0.0), (0.93, 0.11, 7, 0.8), (0.31, 0.05, 6, 1.4),
        (0.80, 0.17, 8, 0.4), (0.52, 0.085, 5, 1.1), (0.15, 0.24, 6, 1.7),
        (0.88, 0.27, 5, 0.6)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Palette.bg
                RadialGradient(colors: [Palette.bg2.opacity(0.9), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 500)
                if scheme == .dark {
                    // warm glow from the lamp (top-right) + soft cool moon glow (top-left)
                    RadialGradient(colors: [Color(hex: "#ffcf7a").opacity(0.26), .clear],
                                   center: UnitPoint(x: 0.93, y: 0.05), startRadius: 0, endRadius: 320)
                    RadialGradient(colors: [Color(hex: "#8e98dd").opacity(0.13), .clear],
                                   center: .topLeading, startRadius: 0, endRadius: 260)
                } else {
                    // soft clouds drifting behind the header
                    Ellipse().fill(Color(hex: "#fce7ea").opacity(0.55))
                        .frame(width: w * 0.55, height: h * 0.13).blur(radius: 28)
                        .position(x: w * 0.24, y: h * 0.10)
                    Ellipse().fill(Color(hex: "#e9eefb").opacity(0.6))
                        .frame(width: w * 0.45, height: h * 0.11).blur(radius: 26)
                        .position(x: w * 0.84, y: h * 0.08)
                }
                ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                    Twinkle(size: s.2, delay: s.3,
                            tint: scheme == .dark ? Color(hex: "#ffe6ad") : Color(hex: "#e9b94e"))
                        .position(x: w * s.0, y: h * s.1)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Sleeping cloud mascot (cozy bedtime companion)

struct SleepyCloud: View {
    var size: CGFloat = 54
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let cx = w * 0.5, cy = h * 0.6
            let cloud = scheme == .dark ? Color(hex: "#cdd6f2") : Color(hex: "#d6def2")
            for p in [(-0.27, 0.05, 0.24), (-0.02, -0.13, 0.30), (0.27, 0.06, 0.24), (0.0, 0.2, 0.32)] {
                let r = w * CGFloat(p.2)
                ctx.fill(Path(ellipseIn: CGRect(x: cx + w * CGFloat(p.0) - r, y: cy + h * CGFloat(p.1) - r, width: 2 * r, height: 2 * r)),
                         with: .color(cloud))
            }
            let ink = Color(hex: "#80708e")
            for sx in [cx - w * 0.12, cx + w * 0.12] {   // closed sleeping eyes
                var eye = Path()
                eye.move(to: CGPoint(x: sx - w * 0.055, y: cy))
                eye.addQuadCurve(to: CGPoint(x: sx + w * 0.055, y: cy), control: CGPoint(x: sx, y: cy + h * 0.06))
                ctx.stroke(eye, with: .color(ink), style: StrokeStyle(lineWidth: max(1, w * 0.03), lineCap: .round))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: cx - w * 0.06, y: cy + h * 0.1))
            smile.addQuadCurve(to: CGPoint(x: cx + w * 0.06, y: cy + h * 0.1), control: CGPoint(x: cx, y: cy + h * 0.16))
            ctx.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: max(1, w * 0.026), lineCap: .round))
            let cheek = Color(hex: "#f2a8a0").opacity(0.5)
            for sx in [cx - w * 0.21, cx + w * 0.21] {
                ctx.fill(Path(ellipseIn: CGRect(x: sx - w * 0.05, y: cy + h * 0.035, width: w * 0.1, height: w * 0.08)), with: .color(cheek))
            }
            let z = Color(hex: scheme == .dark ? "#ffe6ad" : "#cbab5e")
            ctx.draw(Text("z").font(.system(size: w * 0.17, weight: .bold, design: .rounded)).foregroundColor(z),
                     at: CGPoint(x: cx + w * 0.33, y: cy - h * 0.28))
            ctx.draw(Text("z").font(.system(size: w * 0.12, weight: .bold, design: .rounded)).foregroundColor(z),
                     at: CGPoint(x: cx + w * 0.44, y: cy - h * 0.42))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Decorative plant (corner greenery)

struct CornerLeaves: View {
    var size: CGFloat = 96
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let greens = [Color(hex: "#8fc873"), Color(hex: "#79b35d"), Color(hex: "#a9d98c"), Color(hex: "#6aa84f")]
            let stem = CGPoint(x: w * 0.5, y: h * 0.98)
            let leaves: [(CGFloat, CGFloat, Double, CGFloat, Int)] = [
                (0, -0.52, 0, 0.42, 1), (-0.19, -0.34, -34, 0.36, 0), (0.19, -0.36, 34, 0.36, 2),
                (-0.3, -0.15, -62, 0.30, 3), (0.3, -0.17, 62, 0.30, 1), (-0.1, -0.22, -16, 0.34, 2), (0.12, -0.24, 16, 0.34, 0)
            ]
            for lf in leaves {
                ctx.drawLayer { l in
                    l.translateBy(x: stem.x + w * lf.0, y: stem.y + h * lf.1)
                    l.rotate(by: .degrees(lf.2))
                    let len = h * lf.3
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: 0, y: len / 2))
                    leaf.addQuadCurve(to: CGPoint(x: 0, y: -len / 2), control: CGPoint(x: len * 0.38, y: 0))
                    leaf.addQuadCurve(to: CGPoint(x: 0, y: len / 2), control: CGPoint(x: -len * 0.38, y: 0))
                    l.fill(leaf, with: .color(greens[lf.4]))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Warm fairy-light strand (sits at the jar base)

struct FairyLights: View {
    var count = 15
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            // faint string
            var wire = Path()
            for i in 0...count {
                let x = w * CGFloat(i) / CGFloat(count)
                let y = h * 0.45 + sin(CGFloat(i) * 0.8) * h * 0.18
                if i == 0 { wire.move(to: CGPoint(x: x, y: y)) } else { wire.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(wire, with: .color(Color(hex: "#caa86a").opacity(0.35)), lineWidth: 0.8)
            // bulbs with glow
            for i in 0..<count {
                let x = w * (CGFloat(i) + 0.5) / CGFloat(count)
                let y = h * 0.45 + sin((CGFloat(i) + 0.5) * 0.8) * h * 0.18
                let p = CGPoint(x: x, y: y)
                let glow = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                ctx.fill(glow, with: .radialGradient(Gradient(colors: [Color(hex: "#ffd98a").opacity(0.9), .clear]),
                                                     center: p, startRadius: 0, endRadius: 6))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                         with: .color(Color(hex: "#fff1c2")))
            }
        }
        .frame(height: 16)
        .allowsHitTesting(false)
    }
}

// MARK: - Surface the jars rest on (wood in dark, soft shelf in light)

struct JarSurface: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(
                colors: scheme == .dark
                    ? [Color(hex: "#54422d"), Color(hex: "#33261a")]
                    : [Color(hex: "#e8dcc4"), Color(hex: "#d4c6a7")],
                startPoint: .top, endPoint: .bottom))
            .frame(height: 15)
            .overlay(alignment: .top) {   // front edge catching light
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(scheme == .dark ? 0.12 : 0.55))
                    .frame(height: 1.4).padding(.horizontal, 2)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 4, y: 3)
            .allowsHitTesting(false)
    }
}
