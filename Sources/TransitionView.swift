import SwiftUI
import SwiftData

struct TransitionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var session: FocusSession
    let task: Task
    @Query private var profiles: [UserProfile]
    @State private var breathPhase = 0 // 0-5 (3回の吸う/吐く)
    @State private var showBreathing = true
    @State private var circleScale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 完了メッセージ
            VStack(spacing: 8) {
                Text("✅")
                    .font(.system(size: 56))
                Text("\(Int(session.actualMinutes))分集中できた！")
                    .font(.title.bold())
                    .foregroundColor(AppColors.textPrimary)

                Text(RewardEngine.randomPraise())
                    .font(.subheadline)
                    .foregroundColor(AppColors.ember)

                if !session.declaration.isEmpty {
                    Text("「\(session.declaration)」")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    if profiles.first?.enabledTriggers.contains(.accountability) == true {
                        Text("👀 宣言通りできた？")
                            .font(.headline)
                            .foregroundColor(AppColors.ember)
                    }
                }
            }

            // #6 即時ポイント表示
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    VStack {
                        Text("+\(1 + session.bonusEarned) pt")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.fire)
                        Text("獲得")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if session.bonusEarned > 0 {
                        VStack {
                            Text("🎰 ボーナス！")
                                .font(.subheadline.bold())
                                .foregroundColor(AppColors.ember)
                            Text("+\(session.bonusEarned) pt")
                                .font(.caption)
                                .foregroundColor(AppColors.ember)
                        }
                    }
                }

                if let profile = profiles.first, !profile.rewards.isEmpty {
                    let total = profile.totalPoints
                    if let next = profile.rewards.filter({ $0.1 > total }).min(by: { $0.1 < $1.1 }) {
                        Text("次のご褒美まで あと\(next.1 - total) pt → \(next.0)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text("🎁 ご褒美と交換できるよ！")
                            .font(.caption)
                            .foregroundColor(AppColors.ember)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.fire.opacity(0.1)))

            // 深呼吸
            if showBreathing {
                VStack(spacing: 16) {
                    Text("🧘 次に行く前に深呼吸")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    Circle()
                        .fill(AppColors.timerFlow.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: 4), value: circleScale)

                    Text(breathPhase % 2 == 0 ? "吸って..." : "吐いて...")
                        .font(.headline)
                        .foregroundColor(AppColors.timerFlow)
                }
                .onAppear { startBreathing() }
            }

            Spacer()

            // アクション
            VStack(spacing: 12) {
                Button {
                    completeTask()
                    dismiss()
                } label: {
                    Text("次へ進む →")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.fire))
                        .foregroundColor(.white)
                }

                Button {
                    completeTask()
                    dismiss()
                } label: {
                    Text("今日は終わり 🌙")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func completeTask() {
        // finishSession()で完了・ポイント処理済みのため、保存のみ
        try? context.save()
    }

    private func startBreathing() {
        // 3回の呼吸サイクル
        func cycle() {
            guard breathPhase < 6 else {
                showBreathing = false
                return
            }
            circleScale = breathPhase % 2 == 0 ? 1.2 : 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                breathPhase += 1
                cycle()
            }
        }
        cycle()
    }
}
