import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xff) / 255,
                  green: Double((v >> 8) & 0xff) / 255,
                  blue: Double(v & 0xff) / 255)
    }
    /// adaptive light/dark color
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

// MARK: - Bead colour ramp (soft "Morandi" palette; low=taupe → mid=cream → high=dusty colour)

struct BeadColors { var light: Color; var mid: Color; var deep: Color }

enum Ramp {
    // anchors at score 1 / 3 / 5
    static let data: [Metric: (l: [String], m: [String], d: [String])] = [
        .mood:     (["#c8bda6", "#f6edd6", "#f1dda8"], ["#b1a589", "#ecdcb1", "#e6cd83"], ["#9b9075", "#dac79a", "#d6bb6e"]),
        .body:     (["#c5c3b2", "#e9efde", "#cde0bb"], ["#aaa794", "#cedeba", "#a8cb93"], ["#949281", "#b6c89f", "#8ab676"]),
        .tomorrow: (["#c4bdc1", "#ece6f1", "#dccfeb"], ["#a89eaa", "#d6cbe4", "#c3aedd"], ["#928a93", "#bdafcf", "#ad93d2"]),
    ]

    private static func hexComponents(_ hex: String) -> (Double, Double, Double) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        return (Double((v >> 16) & 0xff), Double((v >> 8) & 0xff), Double(v & 0xff))
    }
    private static func lerpHex(_ a: String, _ b: String, _ t: Double) -> Color {
        let (ar, ag, ab) = hexComponents(a), (br, bg, bb) = hexComponents(b)
        return Color(.sRGB,
                     red: (ar + (br - ar) * t) / 255,
                     green: (ag + (bg - ag) * t) / 255,
                     blue: (ab + (bb - ab) * t) / 255)
    }
    private static func lerp3(_ arr: [String], _ score: Double) -> Color {
        let s = min(5, max(1, score))
        return s <= 3 ? lerpHex(arr[0], arr[1], (s - 1) / 2) : lerpHex(arr[1], arr[2], (s - 3) / 2)
    }

    static func colors(_ m: Metric, _ score: Int) -> BeadColors {
        let r = data[m]!
        return BeadColors(light: lerp3(r.l, Double(score)),
                          mid: lerp3(r.m, Double(score)),
                          deep: lerp3(r.d, Double(score)))
    }

    /// accent colour used for titles / selected tab (the score-4 mid tone)
    static func accent(_ m: Metric) -> Color { lerp3(data[m]!.m, 4) }
}

// MARK: - Theme

enum AppTheme: String { case system, light, dark
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum Palette {
    // page / surface
    static let bg      = Color.adaptive("#f4ece0", "#0c1026")
    static let bg2     = Color.adaptive("#f3e4ef", "#141833")
    static let card    = Color.adaptive("#ffffff", "#1a1f3a").opacity(0.0) // cards use per-metric tints below
    static let glass   = Color.adaptive("#ffffff", "#272e50")
    static let txt     = Color.adaptive("#7c6a58", "#cdd0ea")
    static let txtSoft = Color.adaptive("#a8957f", "#9a9fc6")
    static let txtFaint = Color.adaptive("#b9a994", "#767ba3")
    static let title   = Color.adaptive("#6f5c48", "#f0ecdf")
    static let glassBorder = Color.adaptive("#ffffffcc", "#ffffff1a")

    static func cardBG(_ m: Metric) -> Color {
        switch m {
        case .mood: Color.adaptive("#fbeec6", "#3a3018")
        case .body: Color.adaptive("#e3f0d9", "#22331f")
        case .tomorrow: Color.adaptive("#ece2f6", "#2a2142")
        }
    }
    static let cork = Color(hex: "#d9bd8c")
    static let corkDeep = Color(hex: "#c0a06f")
}
