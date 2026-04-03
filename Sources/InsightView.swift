import SwiftUI
import SwiftData

struct InsightView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \CheckIn.timestamp, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]

    var todaySessions: [FocusSession] {
        let cal = Calendar.current
        return sessions.filter { cal.isDateInToday($0.date) && $0.completed }
    }

    var weekSessions: [FocusSession] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())!
        return sessions.filter { $0.date >= weekAgo && $0.completed }
    }

    var totalMinutesToday: Int {
        todaySessions.reduce(0) { $0 + Int($1.actualMinutes) }
    }

    var totalMinutesWeek: Int {
        weekSessions.reduce(0) { $0 + Int($1.actualMinutes) }
    }

    var avgSessionMinutes: Int {
        guard !weekSessions.isEmpty else { return 0 }
        return totalMinutesWeek / weekSessions.count
    }

    var completedTaskCount: Int {
        sessions.filter { $0.completed }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // サマリーカード
                    HStack(spacing: 12) {
                        StatCard(title: "今日", value: "\(totalMinutesToday)分", icon: "flame.fill", color: AppColors.fire)
                        StatCard(title: "今週", value: "\(totalMinutesWeek)分", icon: "calendar", color: AppColors.week)
                        StatCard(title: "完了セッション", value: "\(completedTaskCount)", icon: "checkmark.circle.fill", color: AppColors.success)
                    }
                    .padding(.horizontal)

                    // 週間バー
                    if !weekSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("今週の集中時間")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            WeekBarChart(sessions: weekSessions)
                        }
                        .card()
                        .padding(.horizontal)
                    }

                    // 最近のセッション
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近のセッション")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            ForEach(Array(sessions.prefix(10)), id: \.persistentModelID) { s in
                                HStack {
                                    Text(s.completed ? "✅" : "⏸️")
                                    Text(s.taskName)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Text("\(Int(s.actualMinutes))分")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .card()
                        .padding(.horizontal)
                    }

                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Text("📊")
                                .font(.system(size: 48))
                            Text("まだデータがないよ")
                                .foregroundColor(AppColors.textSecondary)
                            Text("セッションを始めるとここに分析が表示される")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 60)
                    }

                    // ご褒美交換（rewardトリガーON時のみ）
                    if let profile = profiles.first,
                       profile.enabledTriggers.contains(.reward),
                       !profile.rewards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🎁 ご褒美と交換")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text("残り \(profile.totalPoints) pt")
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppColors.fire)
                            }

                            ForEach(Array(profile.rewards.enumerated()), id: \.offset) { _, reward in
                                RewardItem(name: reward.0, cost: reward.1, points: profile.totalPoints) {
                                    profile.totalPoints -= reward.1
                                    try? context.save()
                                }
                            }
                        }
                        .card()
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct WeekBarChart: View {
    let sessions: [FocusSession]

    var dailyMinutes: [Int] {
        let cal = Calendar.current
        return (0..<7).map { dayOffset in
            let date = cal.date(byAdding: .day, value: -6 + dayOffset, to: Date())!
            return sessions
                .filter { cal.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + Int($1.actualMinutes) }
        }
    }

    var maxMinutes: Int { max(dailyMinutes.max() ?? 1, 1) }

    var dayLabels: [String] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return (0..<7).map { dayOffset in
            let date = cal.date(byAdding: .day, value: -6 + dayOffset, to: Date())!
            let weekday = cal.component(.weekday, from: date)
            return ["日","月","火","水","木","金","土"][weekday - 1]
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 4) {
                    if dailyMinutes[i] > 0 {
                        Text("\(dailyMinutes[i])")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == 6 ? AppColors.fire : AppColors.fire.opacity(0.5))
                        .frame(height: max(CGFloat(dailyMinutes[i]) / CGFloat(maxMinutes) * 80, dailyMinutes[i] > 0 ? 8 : 2))
                    Text(dayLabels[i])
                        .font(.system(size: 10))
                        .foregroundColor(i == 6 ? AppColors.textPrimary : AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 110)
    }
}

struct RewardItem: View {
    let name: String
    let cost: Int
    let points: Int
    let onRedeem: () -> Void
    @State private var redeemed = false

    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            if redeemed {
                Text("🎉 交換済み！")
                    .font(.caption)
                    .foregroundColor(AppColors.success)
            } else {
                Button {
                    onRedeem()
                    withAnimation { redeemed = true }
                } label: {
                    Text("\(cost) pt")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(points >= cost ? AppColors.fire : AppColors.progressEmpty))
                        .foregroundColor(.white)
                }
                .disabled(points < cost)
            }
        }
        .padding(.vertical, 4)
    }
}
