import SwiftUI

struct JarView: View {
    let metric: Metric
    let scores: [Int]        // oldest first; newest end up on top
    @Environment(\.colorScheme) private var scheme

    private let beadCap = 70

    private var jarShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 34,
                               bottomTrailingRadius: 34, topTrailingRadius: 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            cork
            glass
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.0 : 0.10), radius: 10, y: 8)
    }

    // MARK: cork lid
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

    // MARK: realistic glass body
    private var glass: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let beads = laidOutBeads(width: w, height: h)
            ZStack {
                // 1) glass body — edges tinted with "thickness" so it reads on any background
                jarShape.fill(bodyGradient)

                // 2) contents (base reflection + beads), clipped to the jar
                ZStack {
                    Ellipse()                                   // soft floor under the beads
                        .fill(baseShadow)
                        .frame(width: w * 0.80, height: h * 0.11)
                        .position(x: w * 0.5, y: h - h * 0.05)
                    ForEach(beads.indices, id: \.self) { i in
                        let b = beads[i]
                        BeadView(colors: Ramp.colors(metric, b.score), size: b.d, sparkle: b.score >= 5)
                            .position(x: b.center.x, y: b.center.y)
                    }
                }
                .clipShape(jarShape)

                // 3) front-glass highlights (over the beads → looks like real glass)
                Capsule()                                       // broad left specular streak
                    .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.5 : 0.9), .white.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.085, height: h * 0.6)
                    .blur(radius: 2.5)
                    .position(x: w * 0.22, y: h * 0.36)
                Capsule()                                       // thin bright right edge
                    .fill(.white.opacity(scheme == .dark ? 0.22 : 0.55))
                    .frame(width: w * 0.028, height: h * 0.48)
                    .blur(radius: 1.4)
                    .position(x: w * 0.865, y: h * 0.42)
                Ellipse()                                       // glass rim / mouth under the cork
                    .stroke(rimColor, lineWidth: 1.4)
                    .frame(width: w * 0.7, height: h * 0.05)
                    .position(x: w * 0.5, y: h * 0.035)

                // 4) crisp glass outline (the visible edge)
                jarShape.stroke(outlineGradient, lineWidth: 1.7)
            }
        }
    }

    // MARK: layout
    private struct LaidBead { var center: CGPoint; var d: CGFloat; var score: Int }

    private func laidOutBeads(width w: CGFloat, height h: CGFloat) -> [LaidBead] {
        var used = scores
        if used.count > beadCap {
            let step = Double(used.count) / Double(beadCap)
            used = (0..<beadCap).map { used[Int(Double($0) * step)] }
        }
        let n = used.count
        guard n > 0, w > 1 else { return [] }
        let base = w * 0.16
        let r = min(max(base * sqrt(CGFloat(16) / CGFloat(n)), w * 0.058), w * 0.17)
        var rng = SeededRNG(seed: UInt64(n &* 9173 &+ metric.rawValue.count))
        let radii: [CGFloat] = used.map { _ in r * CGFloat.random(in: 0.86...1.16, using: &rng) }
        let centers = packDrop(width: w, height: h, radii: radii, seed: UInt64(n &* 31 &+ 7))
        return zip(zip(centers, radii), used).map { LaidBead(center: $0.0, d: $0.1 * 2, score: $1) }
    }

    // MARK: colors (adaptive)
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

    private var baseShadow: RadialGradient {
        scheme == .dark
        ? RadialGradient(colors: [Color(hex: "#10182f").opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 60)
        : RadialGradient(colors: [Color(hex: "#c7b994").opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 60)
    }
}
