import SwiftUI
import SwiftData

struct FlowTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var session: FocusSession
    let task: Task
    @Query private var profiles: [UserProfile]

    @State private var elapsed: Int = 0
    @State private var timer: Timer?
    @State private var clockTimer: Timer?
    @State private var currentTime = Date()
    @State private var phase: TimerPhase = .initial
    @State private var showCheckIn = false
    @State private var nextCheckInAt: Int = 0
    @State private var checkInInterval: Int = 600
    @State private var showTransition = false
    @State private var deadlineRemaining: Int = 0
    @State private var inDeadlineCountdown = false
    @State private var backgroundedAt: Date?
    @State private var deadlineUsed = false

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
                        // #7 現在時刻（時間盲対策）
                        Text(currentTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
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

                        // #1 選択肢を2つに絞る（deadlineのみ追加）
                        if isDeadlineMode && !deadlineUsed {
                            Button("⏰ 残り\(session.plannedMinutes - 2)分でカウントダウン") {
                                deadlineRemaining = (session.plannedMinutes - 2) * 60
                                inDeadlineCountdown = true
                                deadlineUsed = true
                                phase = .flowing
                                nextCheckInAt = elapsed + randomInterval()
                                startTimer()
                            }
                            .buttonStyle(FlowButtonStyle(color: AppColors.ember))
                        }

                        Button("続ける 🔥") {
                            phase = .flowing
                            nextCheckInAt = elapsed + randomInterval()
                            startTimer()
                        }
                        .buttonStyle(FlowButtonStyle(color: AppColors.fire))

                        Button("終わる ✅") {
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
                        // #5 チェックイン可視化
                        if !showCheckIn {
                            let secsUntil = max(0, nextCheckInAt - elapsed)
                            Text("次のチェックイン: 約\(secsUntil / 60)分後")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
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
            .onAppear {
                startTimer()
                clockTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    currentTime = Date()
                }
            }
            .onDisappear {
                timer?.invalidate()
                clockTimer?.invalidate()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    if timer != nil { backgroundedAt = Date() }
                } else if phase == .active {
                    if let bg = backgroundedAt {
                        let gap = Int(Date().timeIntervalSince(bg))
                        elapsed += gap
                        if inDeadlineCountdown {
                            deadlineRemaining = max(0, deadlineRemaining - gap)
                        }
                        backgroundedAt = nil
                    }
                }
            }
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
        guard !showTransition else { return }
        timer?.invalidate()
        timer = nil
        session.actualSeconds = elapsed
        session.endedAt = Date()
        session.completed = true
        let bonus = RewardEngine.calculateBonus()
        session.bonusEarned = bonus

        // タスクを完了マーク
        task.isCompleted = true
        task.completedAt = Date()

        // ポイント加算 + ストリーク更新
        if let profile = profiles.first {
            profile.totalPoints += 1 + bonus

            // #2 フレキシブルストリーク（1日スキップ許容）
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            if let last = profile.lastSessionDate {
                let lastDay = cal.startOfDay(for: last)
                let daysDiff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
                if daysDiff == 0 {
                    // 今日すでに完了済み → ストリーク変化なし
                } else if daysDiff <= 2 {
                    // 昨日 or 1日スキップ → 継続
                    profile.streakCount += 1
                } else {
                    // 2日以上空いた → リセット
                    profile.streakCount = 1
                }
            } else {
                profile.streakCount = 1
            }
            profile.lastSessionDate = Date()
        }

        try? context.save()
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
