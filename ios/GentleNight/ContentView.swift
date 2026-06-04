import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @AppStorage("gentle-night.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var tab = 0

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // background
            backdrop.ignoresSafeArea()

            TabView(selection: $tab) {
                TonightView()
                    .tabItem { Label("Tonight", systemImage: "moon.fill") }.tag(0)
                TrendsView()
                    .tabItem { Label("Trends", systemImage: "circle.grid.2x2.fill") }.tag(1)
            }
            .tint(Color(hex: "#e0a92e"))

            // theme toggle (top-right, like the web)
            Button {
                themeRaw = (resolvedDark ? AppTheme.light : AppTheme.dark).rawValue
            } label: {
                Image(systemName: resolvedDark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.txt)
                    .frame(width: 42, height: 42)
                    .background(Palette.glass.opacity(0.6), in: Circle())
                    .overlay(Circle().stroke(Palette.glassBorder, lineWidth: 1))
            }
            .padding(.top, 8).padding(.trailing, 16)
        }
        .environmentObject(store)
        .preferredColorScheme(theme.colorScheme)
    }

    private var resolvedDark: Bool {
        switch theme { case .dark: true; case .light: false; case .system: systemScheme == .dark }
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
