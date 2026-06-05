import SwiftUI
import Combine

// MARK: - Metric

enum Metric: String, CaseIterable, Identifiable {
    case mood, body, tomorrow
    var id: String { rawValue }

    var titleEN: String {
        switch self { case .mood: "Mood"; case .body: "Body"; case .tomorrow: "Tomorrow" }
    }
    var titleZH: String {
        switch self { case .mood: "心情"; case .body: "身体"; case .tomorrow: "期待" }
    }
    var question: String {
        switch self {
        case .mood: "今天整体开心吗？"
        case .body: "今天身体舒服吗？"
        case .tomorrow: "对明天感觉怎么样？"
        }
    }
    var lowLabel: String {
        switch self { case .mood: "很差"; case .body: "很累"; case .tomorrow: "很抗拒" }
    }
    var highLabel: String {
        switch self { case .mood: "很好"; case .body: "状态很好"; case .tomorrow: "很期待" }
    }
    var symbol: String {
        switch self { case .mood: "sun.max.fill"; case .body: "leaf.fill"; case .tomorrow: "sparkles" }
    }
}

// MARK: - Entry

struct Entry: Codable, Identifiable {
    var date: String           // "yyyy-MM-dd"
    var mood: Int
    var body: Int
    var tomorrow: Int
    var id: String { date }

    func score(_ m: Metric) -> Int {
        switch m { case .mood: mood; case .body: body; case .tomorrow: tomorrow }
    }
}

// MARK: - Range

enum TrendRange: String, CaseIterable, Identifiable {
    case d7 = "7天", d30 = "30天", m3 = "3个月", y1 = "1年"
    var id: String { rawValue }
    var days: Int {
        switch self { case .d7: 7; case .d30: 30; case .m3: 90; case .y1: 365 }
    }
}

// MARK: - Store

final class Store: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    private let key = "gentle-night.entries"

    init() { load() }

    static func todayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func parse(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? .distantPast
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded.sorted { $0.date < $1.date }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var today: Entry? { entries.first { $0.date == Self.todayKey() } }

    func upsertToday(mood: Int, body: Int, tomorrow: Int) {
        let k = Self.todayKey()
        let rec = Entry(date: k, mood: mood, body: body, tomorrow: tomorrow)
        if let i = entries.firstIndex(where: { $0.date == k }) { entries[i] = rec }
        else { entries.append(rec) }
        entries.sort { $0.date < $1.date }
        save()
    }

    /// entries within the last `range.days`, oldest first (newest end → top of jar)
    func inRange(_ range: TrendRange) -> [Entry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -(range.days - 1),
                                           to: Calendar.current.startOfDay(for: Date()))!
        return entries.filter { parse($0.date) >= cutoff }.sorted { $0.date < $1.date }
    }

    func average(_ m: Metric, in range: TrendRange) -> Double? {
        let vals = inRange(range).map { $0.score(m) }
        guard !vals.isEmpty else { return nil }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }
}

// MARK: - Insights (data-driven, gentle/healing tone)

enum Insights {
    static func text(for m: Metric, average: Double?) -> String {
        guard let a = average else { return none[m]! }
        if a >= 3.5 { return high[m]! }
        if a >= 2.0 { return mid[m]! }
        return low[m]!
    }
    static let none: [Metric: String] = [
        .mood: "今晚落下\n第一颗珠子，\n开始记录\n你的温柔吧。",
        .body: "记录下\n今天的身体，\n听听它\n说什么。",
        .tomorrow: "写下对明天\n的小心情，\n种下一点\n期待吧。",
    ]
    static let low: [Metric: String] = [
        .mood: "最近有些\n起伏呢，\n抱抱你，\n一切都会好。",
        .body: "身体想要\n多歇一歇，\n好好疼疼\n自己呀。",
        .tomorrow: "对明天\n可以慢慢来，\n先把今天\n温柔收好。",
    ]
    static let mid: [Metric: String] = [
        .mood: "心情有起有落，\n但你都稳稳\n接住了，\n很棒。",
        .body: "身体偶尔会累，\n记得喝口水、\n早点休息。",
        .tomorrow: "对明天\n有期待也有思量，\n一步步\n都算数。",
    ]
    static let high: [Metric: String] = [
        .mood: "最近心情\n大多明亮，\n好好收着\n这份暖。",
        .body: "身体状态\n挺不错，\n继续好好\n照顾自己。",
        .tomorrow: "你对明天\n满怀期待，\n这份光\n很珍贵。",
    ]
}
