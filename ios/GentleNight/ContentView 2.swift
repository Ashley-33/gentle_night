import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @AppStorage("gentle-night.theme") private var themeRaw = AppTheme.system.rawValue
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
    }
}

#Preview { ContentView() }
