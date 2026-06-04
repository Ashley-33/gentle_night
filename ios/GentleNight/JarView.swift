import SwiftUI

struct JarView: View {
    let metric: Metric
    let scores: [Int]        // oldest first; newest end up on top
    @Environment(\.colorScheme) private var scheme

    private let beadCap = 70

    var body: some View {
        VStack(spacing: 0) {
            // cork lid
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(hex: "#ecd3a6"), Color(hex: "#cba775")],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 20)
                Capsule()
                    .fill(Color(hex: "#e6c89a"))
                    .frame(height: 7).padding(.horizontal, 8).offset(y: -3)
            }
            .frame(width: 64)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
            .zIndex(2)

            // glass body
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let beads = laidOutBeads(width: w, height: h)
                ZStack(alignment: .topLeading) {
                    // glass
                    UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 28,
                                           bottomTrailingRadius: 28, topTrailingRadius: 8)
                        .fill(glassFill)
                        .overlay(
                            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 28,
                                                   bottomTrailingRadius: 28, topTrailingRadius: 8)
                                .stroke(Palette.glassBorder, lineWidth: 1.5)
                        )

                    // beads
                    ForEach(beads.indices, id: \.self) { i in
                        let b = beads[i]
                        BeadView(colors: Ramp.colors(metric, b.score), size: b.d, sparkle: b.score >= 5)
                            .position(x: b.center.x, y: b.center.y)
                    }

                    // front specular streak
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.14)
                        .blur(radius: 3)
                        .padding(.top, h * 0.06)
                        .padding(.leading, w * 0.12)
                        .allowsHitTesting(false)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 28,
                                                  bottomTrailingRadius: 28, topTrailingRadius: 8))
            }
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.0 : 0.12), radius: 12, y: 10)
    }

    private struct LaidBead { var center: CGPoint; var d: CGFloat; var score: Int }

    private func laidOutBeads(width w: CGFloat, height h: CGFloat) -> [LaidBead] {
        var used = scores
        if used.count > beadCap {                   // even sample for long ranges
            let step = Double(used.count) / Double(beadCap)
            used = (0..<beadCap).map { used[Int(Double($0) * step)] }
        }
        let n = used.count
        guard n > 0, w > 1 else { return [] }
        let base = w * 0.16
        let r = min(max(base * (16.0 / Double(n)).squareRoot(), w * 0.058), w * 0.17)
        var rng = SeededRNG(seed: UInt64(n &* 9173 &+ metric.rawValue.count))
        let radii = used.map { _ in r * CGFloat.random(in: 0.86...1.16, using: &rng) }
        let centers = packDrop(width: w, height: h, radii: radii, seed: UInt64(n &* 31 &+ 7))
        return zip(zip(centers, radii), used).map { LaidBead(center: $0.0, d: $0.1 * 2, score: $1) }
    }

    private var glassFill: LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(hex: "#b4c3fa").opacity(0.22), .clear, .clear, Color(hex: "#b9c8fa").opacity(0.26)],
                         startPoint: .leading, endPoint: .trailing)
        : LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.06), .clear, .white.opacity(0.08), .white.opacity(0.55)],
                         startPoint: .leading, endPoint: .trailing)
    }
}
