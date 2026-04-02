import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedTriggers: Set<TriggerType> = []
    @State private var musicSource: MusicSource?
    @State private var page = 0
    var onComplete: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                // Page 0: コンセプト
                onboardingPage(
                    emoji: "🔥",
                    title: "ADHD Igniter",
                    subtitle: "自分だけの集中スイッチを見つけよう",
                    body: "このアプリはADHDの脳科学に基づいて設計されています。\n\nポモドーロは25分の固定タイマー。\nでもADHDの脳には合わない。",
                    buttonText: "なぜ？"
                ).tag(0)

                // Page 1: 科学的根拠
                onboardingPage(
                    emoji: "🧠",
                    title: "ADHDの脳は違う",
                    subtitle: nil,
                    body: "• タスクを始めるのが一番難しい\n\n• やっと集中できた頃に\n　25分を迎えて中断される\n\n• 「頑張れ」だけじゃ動けない\n\n\nだからADHDの脳に合った\n着火剤が必要",
                    buttonText: "どうやって？"
                ).tag(1)

                // Page 2: 使い方
                onboardingPage(
                    emoji: "📋",
                    title: "3ステップで着火",
                    subtitle: nil,
                    body: "🧠 頭の中を全部書き出す\n　→ それだけで脳の負荷が下がる\n\n📅 今日やることを絞ることで\n　脳に安心感を与える\n\n🔥 まずは2分だけ強制的にやってみる\n　→ 火がついたらそれを持続させる",
                    buttonText: "次へ"
                ).tag(2)

                // Page 3: 持続
                onboardingPage(
                    emoji: "🔬",
                    title: "火を絶やさない方法",
                    subtitle: nil,
                    body: "着火した集中を持続させる方法が\n研究でわかっています。\n\n人によって効くスイッチは違う。\n次のページから\n自分に合った方法を選んでみて。",
                    buttonText: "選んでみる"
                ).tag(3)

                // Page 4: トリガー選択
                triggerSelectionPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(AppColors.background.ignoresSafeArea())
        }
    }

    private func onboardingPage(emoji: String, title: String, subtitle: String?, body: String, buttonText: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Text(emoji).font(.system(size: 64))
            Text(title).font(.largeTitle.bold()).foregroundColor(AppColors.textPrimary)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundColor(AppColors.textSecondary)
            }
            Text(body)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation { page += 1 }
            } label: {
                Text(buttonText)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.fire))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    private var triggerSelectionPage: some View {
        ScrollView {
                VStack(spacing: 32) {
                    // トリガー選択
                    VStack(spacing: 8) {
                        Text("🎯")
                            .font(.system(size: 48))
                        Text("集中トリガーを選ぼう")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.textPrimary)
                        Text("複数選べます")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {

                        ForEach(TriggerType.allCases) { trigger in
                            Button {
                                if selectedTriggers.contains(trigger) {
                                    selectedTriggers.remove(trigger)
                                } else {
                                    selectedTriggers.insert(trigger)
                                }
                            } label: {
                                HStack {
                                    Text(trigger.icon)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trigger.label)
                                            .foregroundColor(AppColors.textPrimary)
                                        Text(trigger.hint)
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    if selectedTriggers.contains(trigger) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.fire)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedTriggers.contains(trigger) ? AppColors.fire.opacity(0.15) : AppColors.cardBackground)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 音楽選択
                    if selectedTriggers.contains(.music) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("音楽アプリは？")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: 12) {
                                ForEach(MusicSource.allCases, id: \.self) { source in
                                    Button {
                                        musicSource = source
                                    } label: {
                                        Text(source.label)
                                            .frame(maxWidth: .infinity)
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(musicSource == source ? AppColors.fire.opacity(0.15) : AppColors.cardBackground)
                                            )
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // アプリの外でできること
                    VStack(alignment: .leading, spacing: 8) {
                        Text("アプリの外でも効くこと")
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.textSecondary)
                        Text("🏠 いつもと違う場所でやってみる")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("👥 誰かと一緒にやる・宣言する")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal)

                    // 開始ボタン
                    Button {
                        let profile = UserProfile()
                        profile.enabledTriggers = Array(selectedTriggers)
                        profile.preferredMusicSourceRaw = musicSource?.rawValue
                        profile.setupCompleted = true
                        context.insert(profile)
                        ADHDIgniterApp.scheduleMorningReminder(hour: 8)
                        onComplete?()
                    } label: {
                        Text("始める 🔥")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedTriggers.isEmpty ? AppColors.progressEmpty : AppColors.fire)
                            )
                            .foregroundColor(.white)
                    }
                    .disabled(selectedTriggers.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
    }
}
