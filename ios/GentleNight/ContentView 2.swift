import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @AppStorage("gentle-night.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("gentle-night.onboarded") private var onboarded = false
    @State private var tab = 0

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        ZStack {
            // background
            AmbientBackdrop()

            TabView(selection: $tab) {
                TonightView()
                    .tabItem { Label("Tonight", systemImage: "moon.fill") }.tag(0)
                TrendsView()
                    .tabItem { Label("Trends", systemImage: "circle.grid.2x2.fill") }.tag(1)
            }
            .tint(Color(hex: "#e0a92e"))
        }
        .environmentObject(store)
        .preferredColorScheme(theme.colorScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !onboarded },
            set: { presented in if !presented { onboarded = true } })) {
            OnboardingView { onboarded = true }
                .preferredColorScheme(theme.colorScheme)
        }
    }
}

// MARK: - First-launch onboarding (the gentle "why")

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0
    @Environment(\.colorScheme) private var scheme
    private let total = 4

    private let titles = ["温柔夜记", "三个温柔的问题", "每天,一颗珠子", "这里没有打卡压力"]
    private let ens    = ["Gentle Night", "", "", ""]
    private let bodies = [
        "睡前花几秒,温柔地看见今天的自己。\n不评判,只是好好地和自己待一会儿。",
        "今天的心情、身体,和对明天的期待——\n给它们各打个分。怎样都好,真实就够了。",
        "每条记录,都化作一颗珠子落进玻璃罐。\n日子久了,你会看见自己被温柔地积累。",
        "没有目标,没有完美,没有连续天数。\n只是温柔地,陪你度过每一个夜晚。"
    ]

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()   // opaque base so nothing shows through
            AmbientBackdrop()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("跳过") { onDone() }
                        .font(.system(size: 14)).foregroundStyle(Palette.txtFaint)
                        .padding(.trailing, 22).padding(.top, 10)
                }
                TabView(selection: $page) {
                    ForEach(0..<total, id: \.self) { i in page(i).tag(i) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeOut(duration: 0.25), value: page)

                HStack(spacing: 7) {   // dots
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color(hex: "#e0a92e") : Palette.txtFaint.opacity(0.35))
                            .frame(width: i == page ? 18 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 18)

                Button {
                    if page < total - 1 { withAnimation { page += 1 } } else { onDone() }
                } label: {
                    Text(page < total - 1 ? "下一步" : "开始今晚  🌙")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(scheme == .dark ? Color(hex: "#f6e4b0") : Color(hex: "#8a6a2e"))
                        .background(
                            LinearGradient(colors: scheme == .dark
                                           ? [Color(hex: "#785a2d"), Color(hex: "#503a1c")]
                                           : [Color(hex: "#f8ecc8"), Color(hex: "#f1dca0")],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 30).padding(.bottom, 34)
            }
        }
    }

    @ViewBuilder private func page(_ i: Int) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)
            illustration(i).frame(height: 196)
            VStack(spacing: 7) {
                Text(titles[i]).font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.title)
                if !ens[i].isEmpty {
                    Text(ens[i]).font(.system(size: 14, design: .rounded)).foregroundStyle(Palette.txtFaint)
                }
            }
            Text(bodies[i]).font(.system(size: 15)).foregroundStyle(Palette.txtSoft)
                .multilineTextAlignment(.center).lineSpacing(6).padding(.horizontal, 34)
            Spacer(minLength: 8)
        }
    }

    @ViewBuilder private func illustration(_ i: Int) -> some View {
        switch i {
        case 0:
            ZStack {
                MoonView(glow: true).frame(width: 116, height: 116)
                Twinkle(size: 17, delay: 0.0, tint: Color(hex: "#e9b94e")).offset(x: 74, y: -54)
                Twinkle(size: 11, delay: 0.6, tint: Color(hex: "#e9b94e")).offset(x: -78, y: -16)
                Twinkle(size: 13, delay: 1.1, tint: Color(hex: "#e9b94e")).offset(x: 58, y: 56)
            }
        case 1:
            HStack(spacing: 20) {
                ForEach([Metric.mood, .body, .tomorrow]) { m in
                    VStack(spacing: 8) {
                        Mascot(metric: m, size: 64)
                        Text(m == .mood ? "心情" : m == .body ? "身体" : "明天")
                            .font(.system(size: 12)).foregroundStyle(Palette.txtSoft)
                    }
                }
            }
        case 2:
            OnboardJar()
        default:
            ZStack {
                Image(systemName: "heart.fill").font(.system(size: 72))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#f6c0b8"), Color(hex: "#ec9a9a")],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: "#f0a8a0").opacity(0.5), radius: 12)
                Twinkle(size: 14, delay: 0.3, tint: Color(hex: "#e9b94e")).offset(x: 62, y: -42)
                Twinkle(size: 10, delay: 0.9, tint: Color(hex: "#e9b94e")).offset(x: -64, y: 30)
            }
        }
    }
}

// MARK: - Static decorative jar for onboarding (no physics)

struct OnboardJar: View {
    @Environment(\.colorScheme) private var scheme
    // (xFrac, yFrac, metric, score)
    private let beads: [(CGFloat, CGFloat, Metric, Int)] = [
        (0.30, 0.86, .mood, 4), (0.54, 0.88, .body, 3), (0.74, 0.85, .tomorrow, 5),
        (0.40, 0.71, .tomorrow, 4), (0.63, 0.70, .mood, 5), (0.50, 0.56, .body, 4)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                JarGlass.shape().fill(JarGlass.backWall(scheme))
                ZStack {
                    ForEach(0..<beads.count, id: \.self) { i in
                        let b = beads[i]
                        BeadView(colors: Ramp.colors(b.2, b.3), size: w * 0.27, sparkle: b.3 >= 5)
                            .position(x: w * b.0, y: h * b.1)
                    }
                }
                .clipShape(JarGlass.shape())
                JarFrontGlass()
                ZStack(alignment: .top) {   // cork
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color(hex: "#ecd3a6"), Color(hex: "#cba775")],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.78, height: 22)
                    Capsule().fill(Color(hex: "#e6c89a")).frame(width: w * 0.62, height: 7).offset(y: -3)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
                .position(x: w * 0.5, y: 6)
            }
        }
        .frame(width: 150, height: 188)
    }
}

#Preview { ContentView() }
