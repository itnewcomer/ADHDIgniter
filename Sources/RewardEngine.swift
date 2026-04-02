import Foundation

enum RewardEngine {
    // 変動報酬: 20%の確率でボーナス
    static func calculateBonus() -> Int {
        Int.random(in: 1...5) == 1 ? Int.random(in: 1...5) : 0
    }

    // ランダム褒め言葉
    static func randomPraise() -> String {
        let phrases = [
            "始められた！それだけですごい 🔥",
            "いい調子！ 💪",
            "集中力が上がってきてる 📈",
            "この勢いで行こう 🚀",
            "素晴らしい集中力 ✨",
            "脳が喜んでる 🧠",
            "フロー状態に入ってきた 🌊",
            "今日のあなた、最高 👏",
        ]
        return phrases.randomElement()!
    }
}
