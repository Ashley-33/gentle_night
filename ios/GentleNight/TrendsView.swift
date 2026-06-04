import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var scheme
    @State private var range: TrendRange = .d7
    @State private var restQuote = Quotes.random(Quotes.rest)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // header
                VStack(alignment: .leading, spacing: 4) {
                    Text("✨ Your gentle patterns")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.title)
                    Text("你的状态，正在被温柔看见。")
                        .font(.system(size: 13)).foregroundStyle(Palette.txtSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 48)

                // range pills
                HStack(spacing: 6) {
                    ForEach(TrendRange.allCases) { r in
                        Text(r.rawValue)
                            .font(.system(size: 13.5, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background {
                                if range == r {
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(LinearGradient(colors: [Color(hex: "#f6d98f"), Color(hex: "#efc463")],
                                                             startPoint: .top, endPoint: .bottom))
                                }
                            }
                            .foregroundStyle(range == r ? Color(hex: "#7a5b22") : Palette.txtSoft)
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { range = r } }
                    }
                }
                .padding(5)
                .background(Palette.glass.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.glassBorder, lineWidth: 1))
                .padding(.top, 14)

                // jar labels
                HStack(spacing: 12) {
                    ForEach(Metric.allCases) { m in
                        HStack(spacing: 4) {
                            Image(systemName: m.symbol).font(.system(size: 13)).foregroundStyle(Ramp.accent(m))
                            Text(m.titleEN).font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Ramp.accent(m))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 26)

                // jars
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Metric.allCases) { m in
                        JarView(metric: m, scores: store.inRange(range).map { $0.score(m) })
                            .frame(maxWidth: .infinity).frame(height: 250)
                    }
                }
                .padding(.top, 8)

                // insights
                HStack(alignment: .top, spacing: 9) {
                    ForEach(Metric.allCases) { m in
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: m.symbol).font(.system(size: 14)).foregroundStyle(Ramp.accent(m))
                            Text(Insights.text(for: m, average: store.average(m, in: range)))
                                .font(.system(size: 11.5)).foregroundStyle(Palette.txt)
                                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11).padding(.vertical, 13)
                        .background(Palette.glass.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.glassBorder, lineWidth: 1))
                    }
                }
                .padding(.top, 16)

                // rest banner
                HStack {
                    MoonView(glow: scheme == .dark).frame(width: 34, height: 34)
                    Text(restQuote)
                        .font(.system(size: 13)).italic(restQuote.range(of: "[a-zA-Z]", options: .regularExpression) != nil)
                        .foregroundStyle(Palette.txt).frame(maxWidth: .infinity)
                    Image(systemName: "heart.fill").font(.system(size: 13)).foregroundStyle(Color(hex: "#f0c95a"))
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color.adaptive("#ddd2ef", "#3c3764"), Color.adaptive("#cfd9f0", "#282850")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
                .padding(.top, 22)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
    }
}
