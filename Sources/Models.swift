import Foundation
import SwiftData

// MARK: - Enums

enum TimeHorizon: String, Codable, CaseIterable {
    case today, week, month, quarter, someday

    var label: String {
        switch self {
        case .today: "今日"
        case .week: "今週"
        case .month: "今月"
        case .quarter: "3ヶ月"
        case .someday: "いつかやる"
        }
    }

    var icon: String {
        switch self {
        case .today: "flame.fill"
        case .week: "calendar"
        case .month: "calendar.badge.clock"
        case .quarter: "flag.fill"
        case .someday: "tray.fill"
        }
    }
}

enum TriggerType: String, Codable, CaseIterable, Identifiable {
    case accountability  // 宣言モード
    case deadline        // カウントダウン
    case music           // BGM
    case reward          // ご褒美
    case singleTask      // 1つだけ表示
    case exercise        // 運動プライミング

    var id: String { rawValue }

    var label: String {
        switch self {
        case .accountability: "誰かに見られている感覚"
        case .deadline: "締め切りがある"
        case .music: "音楽やノイズ"
        case .reward: "ご褒美がある"
        case .singleTask: "やることが1つに絞られている"
        case .exercise: "作業前に身体を動かす"
        }
    }

    var icon: String {
        switch self {
        case .accountability: "👀"
        case .deadline: "⏰"
        case .music: "🎵"
        case .reward: "🎁"
        case .singleTask: "🎯"
        case .exercise: "🏃"
        }
    }

    var hint: String {
        switch self {
        case .accountability: "「これやる」と宣言すると、やらなきゃ感が出る"
        case .deadline: "30分以内にタスクを終わらせる！と決めると頑張れる"
        case .music: "お気に入りのBGMで集中モードに切り替える"
        case .reward: "タスク完了数で自分へのご褒美と交換できる！"
        case .singleTask: "目の前の1つだけに集中。他は隠す"
        case .exercise: "作業前に5分だけ身体を動かしてドーパミンを出す"
        }
    }
}

enum CheckInStatus: String, Codable {
    case focused, distracted, warmup
}

enum MusicSource: String, Codable, CaseIterable {
    case spotify, appleMusic

    var label: String {
        switch self {
        case .spotify: "Spotify"
        case .appleMusic: "Apple Music"
        }
    }
}

enum CalendarApp: String, Codable, CaseIterable {
    case apple, google, timetree

    var label: String {
        switch self {
        case .apple: "Appleカレンダー"
        case .google: "Googleカレンダー"
        case .timetree: "TimeTree"
        }
    }

    var icon: String {
        switch self {
        case .apple: "📅"
        case .google: "📆"
        case .timetree: "📅"
        }
    }

    func url(title: String, date: Date?) -> URL? {
        switch self {
        case .apple:
            return URL(string: "calshow://")
        case .google:
            var comps = URLComponents(string: "https://calendar.google.com/calendar/render")!
            var items = [URLQueryItem(name: "action", value: "TEMPLATE"),
                         URLQueryItem(name: "text", value: title)]
            if let date {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd"
                let d = fmt.string(from: date)
                items.append(URLQueryItem(name: "dates", value: "\(d)/\(d)"))
            }
            comps.queryItems = items
            return comps.url
        case .timetree:
            return URL(string: "timetree://")
        }
    }
}

// MARK: - Models

@Model
class Task {
    var name: String
    var icon: String
    var timeHorizonRaw: String
    var dueDate: Date?
    var importance: Int
    var urgency: Int
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?
    var todayOrder: Int?
    var assignedWeekday: Int?  // 1=日,2=月,3=火,4=水,5=木,6=金,7=土
    var assignedWeekOfMonth: Int?  // 1-5
    var createdAt: Date
    var firstStep: String?

    init(name: String, icon: String = "", timeHorizon: TimeHorizon = .today, dueDate: Date? = nil, importance: Int = 2, urgency: Int = 2, order: Int = 0) {
        self.name = name
        self.icon = icon.isEmpty ? Self.autoIcon(for: name) : icon
        self.timeHorizonRaw = timeHorizon.rawValue
        self.dueDate = dueDate
        self.importance = importance
        self.urgency = urgency
        self.order = order
        self.isCompleted = false
        self.createdAt = Date()
    }

    var timeHorizon: TimeHorizon {
        get { TimeHorizon(rawValue: timeHorizonRaw) ?? .today }
        set { timeHorizonRaw = newValue.rawValue }
    }

    var priorityScore: Int { importance * urgency }

    static func autoIcon(for name: String) -> String {
        let n = name.lowercased()
        let map: [(keys: [String], icon: String)] = [
            (["メール", "mail", "slack", "返信", "連絡", "sms", "line"], "💬"),
            (["電話", "call", "tel"], "📞"),
            (["会議", "ミーティング", "meeting", "mtg"], "🤝"),
            (["書く", "企画", "資料", "レポート", "report", "ドキュメント", "doc"], "📝"),
            (["買い物", "買う", "購入", "shop"], "🛒"),
            (["掃除", "片付", "洗", "clean"], "🧹"),
            (["料理", "ご飯", "cook", "食"], "🍳"),
            (["予約", "予定", "アポ", "book"], "📅"),
            (["勉強", "study", "学", "読", "本"], "📚"),
            (["運動", "walk", "散歩", "ジム", "gym"], "🏃"),
            (["病院", "医者", "歯", "薬"], "🏥"),
            (["コード", "code", "プログラ", "開発", "dev", "bug"], "💻"),
            (["デザイン", "design", "アイコン"], "🎨"),
            (["お金", "支払", "振込", "確定申告", "税"], "💰"),
            (["プレゼン", "発表", "スライド"], "📊"),
        ]
        for entry in map {
            if entry.keys.contains(where: { n.contains($0) }) { return entry.icon }
        }
        return "📌"
    }
}

@Model
class BrainDump {
    var date: Date
    var rawText: String
    var processedAt: Date?
    var mood: String?

    init(date: Date = .now, rawText: String = "", mood: String? = nil) {
        self.date = date
        self.rawText = rawText
        self.mood = mood
    }

    var items: [String] {
        rawText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

@Model
class BrainDumpItem {
    var text: String
    var timeHorizonRaw: String?
    var convertedToTask: Bool
    var dumpDate: Date

    init(text: String, dumpDate: Date = .now) {
        self.text = text
        self.convertedToTask = false
        self.dumpDate = dumpDate
    }

    var timeHorizon: TimeHorizon? {
        get { timeHorizonRaw.flatMap { TimeHorizon(rawValue: $0) } }
        set { timeHorizonRaw = newValue?.rawValue }
    }
}

@Model
class FocusSession {
    var date: Date
    var taskName: String
    var declaration: String
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var actualSeconds: Int
    var triggersRaw: String      // カンマ区切りで保存
    var musicSourceRaw: String?
    var completed: Bool
    var rating: Int?
    var bonusEarned: Int
    var feeling: String?

    init(taskName: String, declaration: String = "", triggers: [TriggerType] = []) {
        self.date = Date()
        self.taskName = taskName
        self.declaration = declaration
        self.startedAt = Date()
        self.plannedMinutes = 2
        self.actualSeconds = 0
        self.triggersRaw = triggers.map(\.rawValue).joined(separator: ",")
        self.completed = false
        self.bonusEarned = 0
    }

    var actualMinutes: Double { Double(actualSeconds) / 60.0 }
    var triggersUsed: [TriggerType] {
        triggersRaw.split(separator: ",").compactMap { TriggerType(rawValue: String($0)) }
    }
}

@Model
class CheckIn {
    var sessionDate: Date
    var timestamp: Date
    var statusRaw: String
    var intervalSeconds: Int

    init(sessionDate: Date, status: CheckInStatus, intervalSeconds: Int) {
        self.sessionDate = sessionDate
        self.timestamp = Date()
        self.statusRaw = status.rawValue
        self.intervalSeconds = intervalSeconds
    }

    var status: CheckInStatus { CheckInStatus(rawValue: statusRaw) ?? .focused }
}

@Model
class UserProfile {
    var enabledTriggersRaw: String  // カンマ区切り
    var preferredMusicSourceRaw: String?
    var spotifyPlaylistURL: String?
    var appleMusicPlaylistURL: String?
    var setupCompleted: Bool
    var dailyTaskLimit: Int
    var totalPoints: Int
    var calendarAppRaw: String?
    var morningReminderHour: Int
    var rewardsRaw: String  // カンマ区切り「名前:コスト」

    init() {
        self.enabledTriggersRaw = ""
        self.setupCompleted = false
        self.dailyTaskLimit = 3
        self.totalPoints = 0
        self.morningReminderHour = 8
        self.rewardsRaw = "コーヒー1杯 ☕:3,好きなおやつ 🍫:5,1時間の趣味タイム 🎨:10,自分へのプレゼント 🎁:20"
    }

    var enabledTriggers: [TriggerType] {
        get { enabledTriggersRaw.split(separator: ",").compactMap { TriggerType(rawValue: String($0)) } }
        set { enabledTriggersRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    var preferredMusicSource: MusicSource? {
        get { preferredMusicSourceRaw.flatMap { MusicSource(rawValue: $0) } }
        set { preferredMusicSourceRaw = newValue?.rawValue }
    }

    var calendarApp: CalendarApp? {
        get { calendarAppRaw.flatMap { CalendarApp(rawValue: $0) } }
        set { calendarAppRaw = newValue?.rawValue }
    }

    var rewards: [(String, Int)] {
        get {
            rewardsRaw.split(separator: ",").compactMap { entry in
                let parts = entry.split(separator: ":")
                guard parts.count == 2, let cost = Int(parts[1]) else { return nil }
                return (String(parts[0]), cost)
            }
        }
        set {
            rewardsRaw = newValue.map { "\($0.0):\($0.1)" }.joined(separator: ",")
        }
    }
}
