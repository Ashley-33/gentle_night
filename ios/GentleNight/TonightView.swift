import SwiftUI

struct TonightView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var scheme

    @AppStorage("gentle-night.onboarded") private var onboarded = false
    @State private var scores: [Metric: Int] = [.mood: 4, .body: 4, .tomorrow: 3]
    @State private var heroQuote = Quotes.random(Quotes.hero)
    @State private var savedHint = false
    @State private var showDrop = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if scheme == .dark {
                CornerLeaves(size: 134).offset(x: 30, y: 40).allowsHitTesting(false)
            }
            ScrollView {
                VStack(spacing: 12) {
                    hero
                    ForEach(Metric.allCases) { m in card(m) }
                    goodNight
                    if savedHint {
                        Text(scheme == .dark ? "🌙 今晚的状态，已经收好啦 🌙" : "💛 今晚的状态，已经收好啦 🌙")
                            .font(.system(size: 12)).foregroundStyle(Palette.txtFaint)
                            .transition(.opacity)
                    }
                    Button { onboarded = false } label: {   // replay the gentle intro
                        Label("这是什么 · 重看引导", systemImage: "questionmark.circle")
                            .font(.system(size: 12)).foregroundStyle(Palette.txtFaint.opacity(0.8))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            if showDrop {
                DropOverlay(scores: scores) { showDrop = false }
                    .transition(.opacity)
            }
        }
        .onAppear {
            if let t = store.today { scores = [.mood: t.mood, .body: t.body, .tomorrow: t.tomorrow]; savedHint = true }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tonight").font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.title)
                Text(dateString).font(.system(size: 13)).foregroundStyle(Palette.txtSoft)
                Text(heroQuote).font(.system(size: 13.5)).italic(heroQuote.range(of: "[a-zA-Z]", options: .regularExpression) != nil)
                    .foregroundStyle(Palette.txtSoft).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            Spacer(minLength: 4)
            LampThemeButton().padding(.top, 2)
        }
        .padding(.bottom, 6)
    }

    private func card(_ m: Metric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Mascot(metric: m, size: 42)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.titleEN).font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Ramp.accent(m))
                    Text(m.question).font(.system(size: 13)).foregroundStyle(Palette.txtSoft)
                }
            }
            HStack {
                ForEach(1...5, id: \.self) { v in
                    OrbView(metric: m, value: v, selected: scores[m] == v, showNumber: scheme == .dark)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scores[m] = v }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    if v < 5 { Spacer() }
                }
            }
            HStack {
                Text(m.lowLabel); Spacer(); Text(m.highLabel)
            }
            .font(.system(size: 12)).foregroundStyle(Palette.txtFaint)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Palette.cardBG(m), in: RoundedRectangle(cornerRadius: 26))
    }

    private var goodNight: some View {
        Button {
            store.upsertToday(mood: scores[.mood]!, body: scores[.body]!, tomorrow: scores[.tomorrow]!)
            withAnimation { savedHint = true; showDrop = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "moon.fill")
                Text(scheme == .dark ? "晚安啦" : "Good night")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .foregroundStyle(scheme == .dark ? Color(hex: "#f6e4b0") : Color(hex: "#8a6a2e"))
            .background(
                LinearGradient(colors: scheme == .dark
                               ? [Color(hex: "#785a2d"), Color(hex: "#503a1c")]
                               : [Color(hex: "#f8ecc8"), Color(hex: "#f1dca0")],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(.top, 4)
    }

    private var dateString: String {
        let d = Date(); let cal = Calendar.current
        let wk = ["日","一","二","三","四","五","六"][cal.component(.weekday, from: d) - 1]
        return "\(cal.component(.month, from: d))月\(cal.component(.day, from: d))日  星期\(wk)"
    }
}

// MARK: - Drop into jar animation

private struct DropOverlay: View {
    let scores: [Metric: Int]
    let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var fall = false
    @State private var lid = false
    @State private var leave = false

    private let order: [Metric] = [.mood, .body, .tomorrow]

    var body: some View {
        ZStack {
            Color.black.opacity(scheme == .dark ? 0.5 : 0.16).ignoresSafeArea()
            VStack(spacing: 0) {
                // cork
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(hex: "#ecd3a6"), Color(hex: "#cba775")],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 92, height: 22)
                    .offset(y: lid ? 0 : -44).opacity(lid ? 1 : 0)
                    .zIndex(2)
                // glass with beads — same clear-glass chrome as the Trends jar
                ZStack(alignment: .bottom) {
                    JarGlass.shape(top: 8, bottom: 28).fill(JarGlass.backWall(scheme))
                        .frame(width: 140, height: 210)
                    HStack(spacing: 6) {
                        ForEach(order.indices, id: \.self) { i in
                            BeadView(colors: Ramp.colors(order[i], scores[order[i]]!), size: 40,
                                     sparkle: scores[order[i]]! >= 5)
                                .offset(y: fall ? -14 : -250)
                                .opacity(fall ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(Double(i) * 0.18), value: fall)
                        }
                    }
                    .padding(.bottom, 8)
                    JarFrontGlass(top: 8, bottom: 28)
                        .frame(width: 140, height: 210)
                }
            }
            .scaleEffect(leave ? 0.85 : 1).opacity(leave ? 0 : 1)
            .offset(y: leave ? -34 : 0)
        }
        .onAppear { run() }
    }

    private func run() {
        fall = true
        for i in order.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.18) {
                SoundPlayer.shared.drop(i)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { lid = true }
            SoundPlayer.shared.seal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            SoundPlayer.shared.chime()
            withAnimation(.easeIn(duration: 0.5)) { leave = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onDone() }
    }
}
