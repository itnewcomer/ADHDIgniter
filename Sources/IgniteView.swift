import SwiftUI
import SwiftData

struct IgniteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: Task
    @State private var declaration = ""
    @State private var sessionStarted = false
    @State private var session: FocusSession?
    @State private var deadlineMinutes: Int = 30
    @State private var feeling: String = ""
    @Query private var profiles: [UserProfile]
    @State private var exerciseDone = false

    private var hasDeadlineTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.deadline) == true
    }

    private var hasMusicTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.music) == true
    }

    private var hasRewardTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.reward) == true
    }

    private var hasAccountabilityTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.accountability) == true
    }

    private var hasExerciseTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.exercise) == true
    }

    var body: some View {
        Group {
            if sessionStarted, let session {
                FlowTimerView(session: session, task: task)
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.title3)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)

                        // タスク名
                        VStack(spacing: 8) {
                            Text(task.icon)
                                .font(.system(size: 48))
                            Text(task.name)
                                .font(.title.bold())
                                .foregroundColor(AppColors.textPrimary)
                        }

                        // 宣言入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("これから具体的に何をする？")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text("「〇〇したら、△△する」の形で書くと効果的")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            if hasAccountabilityTrigger {
                                Text("👀 この宣言は記録に残るよ")
                                    .font(.caption)
                                    .foregroundColor(AppColors.ember)
                            }

                            TextField("具体的なアクション...", text: $declaration)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.cardBackground)
                                )
                                .foregroundColor(AppColors.textPrimary)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal)

                        // 締め切りトリガー
                        if hasDeadlineTrigger {
                            VStack(spacing: 8) {
                                Text("⏰ 何分以内にやる？")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.ember)
                                HStack(spacing: 12) {
                                    ForEach([15, 30, 45, 60], id: \.self) { min in
                                        Button {
                                            deadlineMinutes = min
                                        } label: {
                                            Text("\(min)分")
                                                .font(.subheadline.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(deadlineMinutes == min ? AppColors.fire.opacity(0.3) : AppColors.cardBackground)
                                                )
                                                .foregroundColor(deadlineMinutes == min ? AppColors.fire : AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }

                        // accountability: 宣言の強調表示
                        if hasAccountabilityTrigger && !declaration.isEmpty {
                            VStack(spacing: 8) {
                                Text("👀 あなたの宣言")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("「\(declaration)」")
                                    .font(.title3.bold())
                                    .foregroundColor(AppColors.ember)
                                    .multilineTextAlignment(.center)
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.ember.opacity(0.1)))
                                Text("声に出して読んでみよう")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.horizontal)
                        }

                        // 着火ボタン
                        VStack(spacing: 8) {
                            if hasRewardTrigger {
                                Text("🎰 完了したらボーナスチャンス！")
                                    .font(.caption)
                                    .foregroundColor(AppColors.ember)
                            }
                            Text("2分だけやってみよう")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)

                            Button {
                                startSession()
                            } label: {
                                HStack {
                                    Text("🔥")
                                        .font(.title)
                                    Text("着火する")
                                        .font(.title2.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(AppColors.fire)
                                )
                                .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                        }

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }

    private func startSession() {
        let s = FocusSession(taskName: task.name, declaration: declaration)
        s.plannedMinutes = hasDeadlineTrigger ? deadlineMinutes : 2
        s.feeling = feeling.isEmpty ? nil : feeling
        context.insert(s)
        session = s

        // 音楽トリガー: 音楽アプリを開く
        if hasMusicTrigger, let profile = profiles.first {
            let urlStr = profile.preferredMusicSource == .spotify
                ? (profile.spotifyPlaylistURL ?? "spotify://")
                : (profile.appleMusicPlaylistURL ?? "music://")
            if let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
            }
        }

        withAnimation { sessionStarted = true }
    }
}
