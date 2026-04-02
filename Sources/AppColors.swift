import SwiftUI

enum AppColors {
    // 背景: ダークトーン（集中・大人向け）
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.18)
    static let cardShadow = Color.black.opacity(0.3)

    // テキスト
    static let textPrimary = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let textSecondary = Color(red: 0.60, green: 0.60, blue: 0.65)

    // アクセント: 炎（Igniter）
    static let fire = Color(red: 1.0, green: 0.45, blue: 0.15)         // オレンジ炎
    static let fireGlow = Color(red: 1.0, green: 0.30, blue: 0.10)     // 強い炎
    static let ember = Color(red: 1.0, green: 0.70, blue: 0.30)        // 残り火

    // 状態
    static let success = Color(red: 0.30, green: 0.85, blue: 0.50)
    static let warning = Color(red: 1.0, green: 0.80, blue: 0.30)
    static let distracted = Color(red: 0.90, green: 0.45, blue: 0.50)

    // タイマー進行色
    static let timerStart = Color(red: 0.30, green: 0.50, blue: 1.0)   // 青（開始）
    static let timerFlow = Color(red: 0.50, green: 0.30, blue: 1.0)    // 紫（フロー中）
    static let timerDeep = Color(red: 1.0, green: 0.45, blue: 0.15)    // 炎（深い集中）

    // 時間軸
    static let today = Color(red: 1.0, green: 0.45, blue: 0.15)
    static let week = Color(red: 0.50, green: 0.30, blue: 1.0)
    static let month = Color(red: 0.30, green: 0.50, blue: 1.0)
    static let quarter = Color(red: 0.30, green: 0.85, blue: 0.50)
    static let someday = Color(red: 0.50, green: 0.50, blue: 0.55)

    // プログレス
    static let progressEmpty = Color(red: 0.20, green: 0.20, blue: 0.25)
    static let progressFill = Color(red: 1.0, green: 0.45, blue: 0.15)
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground)
                    .shadow(color: AppColors.cardShadow, radius: 4, y: 2)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}
