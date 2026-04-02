import SwiftUI
import SwiftData

struct FlowTimerView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: FocusSession
    let task: Task
    @Query private var profiles: [UserProfile]

    @State private var elapsed: Int = 0
    @State private var timer: Timer?
    @State private var phase: TimerPhase = .initial // 2分チャレンジ
    @State private var showCheckIn = false
    @State private var nextCheckInAt: Int = 0
    @State private var checkInInterval: Int = 600 // 初回10分後
    @State private var showTransition = false
    @State private var deadlineRemaining: Int = 0  // deadline後半のカウントダウン
    @State private var inDeadlineCountdown = false

    enum TimerPhase {
        case initial    // 最初の2分（全員共通）
        case deciding   // 2分後の選択
        case flowing    // 続行中
        case done       // 完了
    }

    var minutes: Int { elapsed / 60 }
    var seconds: Int { elapsed % 60 }
    var isDeadlineMode: Bool { session.plannedMinutes > 2 }
    var progress: Double {
        phase == .initial ? min(Double(elapsed) / 120.0, 1.0) : 0
    }
    var deadlineMin: Int { deadlineRemaining / 60 }
    var deadlineSec: Int { deadlineRemaining % 60 }

    // タイマーの色（時間経過で変化）
    var timerColor: Color {
        if elapsed < 120 { return AppColors.timerStart }
        if elapsed < 600 { return AppColors.timerFlow }
        return AppColors.timerDeep
    }

    var body: some View {
        if showTransition {
            TransitionView(session: session, task: task)
        } else {
            VStack(spacing: 24) {
                // タスク名 + 宣言
                VStack(spacing: 4) {
                    Text("\(task.icon) \(task.name)")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    if !session.declaration.isEmpty {
                        if profiles.first?.enabledTriggers.contains(.accountability) == true {
                            Text("「\(session.declaration)」")
                                .font(.subheadline.bold())
                                .foregroundColor(AppColors.ember)
                        } else {
                            Text("「\(session.declaration)」")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // タイマー表示
                ZStack {
                    // 背景円
                    Circle()
                        .stroke(AppColors.progressEmpty, lineWidth: 8)
                        .frame(width: 200, height: 200)

                    // 進捗円（2分チャレンジ中のみ）
                    if phase == .initial {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                    }

                    // 時間表示
                    VStack(spacing: 4) {
                        if inDeadlineCountdown {
                            Text(String(format: "%d:%02d", deadlineMin, deadlineSec))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(deadlineRemaining < 60 ? AppColors.distracted : timerColor)
                            Text("残り")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text(String(format: "%d:%02d", minutes, seconds))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(timerColor)
                            Text(phaseLabel)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // フェーズ別UI
                switch phase {
                case .initial:
                    VStack(spacing: 12) {
                        Text("2分だけ...🔥")
                            .font(.headline)
                            .foregroundColor(AppColors.ember)
                        Button("✅ もう終わった！") {
                            finishSession()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.success))
                    }

                case .deciding:
                    VStack(spacing: 12) {
                        Text("🎉 2分クリア！着火できた！")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.fire)

                        if isDeadlineMode {
                            Button("⏰ 残り\(session.plannedMinutes - 2)分、カウントダウンする") {
                                deadlineRemaining = (session.plannedMinutes - 2) * 60
                                inDeadlineCountdown = true
                                phase = .flowing
                                nextCheckInAt = elapsed + randomInterval()
                                startTimer()
                            }
                            .buttonStyle(FlowButtonStyle(color: AppColors.ember))
                        }

                        Button("もう少し続ける +5分") {
                            phase = .flowing
                            nextCheckInAt = elapsed + randomInterval()
                            startTimer()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.fire))

                        Button("キリがいいところまで") {
                            phase = .flowing
                            nextCheckInAt = elapsed + randomInterval()
                            startTimer()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.timerFlow))

                        Button("もう十分！終わる") {
                            finishSession()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.success))
                    }

                case .flowing:
                    VStack(spacing: 12) {
                        if inDeadlineCountdown {
                            Text("⏰ 残り \(deadlineMin):\(String(format: "%02d", deadlineSec))")
                                .font(.subheadline)
                                .foregroundColor(deadlineRemaining < 60 ? AppColors.distracted : AppColors.ember)
                        }
                        Button("✅ 完了する") {
                            finishSession()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.success))
                    }

                case .done:
                    EmptyView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .onAppear { startTimer() }
            .onDisappear { timer?.invalidate() }
            .overlay {
                if showCheckIn {
                    CheckInOverlay(
                        elapsed: elapsed,
                        declaration: session.declaration,
                        isAccountability: profiles.first?.enabledTriggers.contains(.accountability) == true,
                        onResponse: { status in
                            let checkIn = CheckIn(sessionDate: session.date, status: status, intervalSeconds: checkInInterval)
                            context.insert(checkIn)

                            // 集中してたら間隔を伸ばす、脱線なら縮める
                            switch status {
                            case .focused: checkInInterval = min(checkInInterval + 300, 1500) // +5分、最大25分
                            case .distracted: checkInInterval = max(checkInInterval - 180, 300) // -3分、最小5分
                            case .warmup: break // 変更なし
                            }
                            nextCheckInAt = elapsed + randomInterval()
                            showCheckIn = false
                        }
                    )
                }
            }
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .initial: "2分チャレンジ中"
        case .deciding: ""
        case .flowing: "フロー中 🌊"
        case .done: "完了！"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1

            // deadlineカウントダウン
            if inDeadlineCountdown {
                deadlineRemaining -= 1
                if deadlineRemaining <= 0 {
                    timer?.invalidate()
                    inDeadlineCountdown = false
                    phase = .deciding
                    return
                }
            }

            // 2分チャレンジ完了（常に120秒）
            if phase == .initial && elapsed >= 120 {
                timer?.invalidate()
                phase = .deciding
            }

            // チェックイン
            if phase == .flowing && !inDeadlineCountdown && elapsed >= nextCheckInAt {
                showCheckIn = true
            }
        }
    }

    private func randomInterval() -> Int {
        // 変動比率: checkInInterval ± 30%
        let variance = Int(Double(checkInInterval) * 0.3)
        return checkInInterval + Int.random(in: -variance...variance)
    }

    private func finishSession() {
        timer?.invalidate()
        session.actualSeconds = elapsed
        session.endedAt = Date()
        session.completed = true
        session.bonusEarned = RewardEngine.calculateBonus()
        phase = .done
        withAnimation { showTransition = true }
    }
}

// MARK: - CheckIn Overlay

struct CheckInOverlay: View {
    let elapsed: Int
    let declaration: String
    let isAccountability: Bool
    let onResponse: (CheckInStatus) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("👀 \(elapsed / 60)分経過")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                if isAccountability && !declaration.isEmpty {
                    Text("「\(declaration)」\nやってる？")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.ember)
                        .multilineTextAlignment(.center)
                } else {
                    Text("今どんな感じ？")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Button("集中できてる 🔥") { onResponse(.focused) }
                    .buttonStyle(FlowButtonStyle(color: AppColors.success))

                Button("ちょっと脱線した 😅") { onResponse(.distracted) }
                    .buttonStyle(FlowButtonStyle(color: AppColors.warning))

                Button("まだウォームアップ中 🐢") { onResponse(.warmup) }
                    .buttonStyle(FlowButtonStyle(color: AppColors.timerStart))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardBackground)
            )
            .padding(32)
        }
    }
}

// MARK: - Button Style

struct FlowButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(configuration.isPressed ? 0.6 : 0.2)))
            .foregroundColor(color)
    }
}
