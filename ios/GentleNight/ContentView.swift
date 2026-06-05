import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @AppStorage("gentle-night.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var tab = 0

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        ZStack {
            // background
            backdrop.ignoresSafeArea()

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
    }

    private var backdrop: some View {
        ZStack {
            Palette.bg
            RadialGradient(colors: [Palette.bg2.opacity(0.9), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 500)
        }
    }
}

#Preview { ContentView() }
