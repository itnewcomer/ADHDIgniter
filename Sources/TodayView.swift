import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Task.order) private var allTasks: [Task]
    @Query private var sessions: [FocusSession]
    @Query private var profiles: [UserProfile]
    @Query(sort: \BrainDump.date, order: .reverse) private var dumps: [BrainDump]
    @Binding var switchToTab: Int
    @State private var selectedTask: Task?
    @State private var editingTask: Task?
    @State private var editName = ""
    @State private var exerciseTimer: Int = 0
    @State private var exerciseTimerRunning = false
    @State private var exerciseTimerObj: Timer?

    private var hasSingleTaskTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.singleTask) == true
    }

    private var hasExerciseTrigger: Bool {
        profiles.first?.enabledTriggers.contains(.exercise) == true
    }

    var todayTasks: [Task] {
        allTasks
            .filter { $0.todayOrder != nil && !$0.isCompleted }
            .sorted { ($0.todayOrder ?? 0) < ($1.todayOrder ?? 0) }
    }

    var completedToday: [Task] {
        allTasks.filter { $0.todayOrder != nil && $0.isCompleted }
    }

    var todayMinutes: Int {
        let cal = Calendar.current
        return sessions
            .filter { cal.isDateInToday($0.date) && $0.completed }
            .reduce(0) { $0 + Int($1.actualMinutes) }
    }

    var didDumpToday: Bool {
        dumps.contains { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    // 今日の集中時間 + #2 ストリーク表示
                    if todayMinutes > 0 || !completedToday.isEmpty {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(AppColors.fire)
                            Text("今日の集中: \(todayMinutes)分")
                                .font(.subheadline.bold())
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text("\(completedToday.count)つ完了")
                                .font(.caption)
                                .foregroundColor(AppColors.success)
                        }
                        .padding(.horizontal)
                    }
                    if let streak = profiles.first?.streakCount, streak > 0 {
                        HStack(spacing: 4) {
                            Text(streak <= 2 ? "🔥" : streak <= 7 ? "🔥🔥" : "🔥🔥🔥")
                            Text("\(streak)日連続継続中！")
                                .font(.caption.bold())
                                .foregroundColor(AppColors.ember)
                        }
                        .padding(.horizontal)
                    }

                    // 今日まだダンプしてない場合の誘導
                    if !didDumpToday && !todayTasks.isEmpty {
                        Button { switchToTab = 0 } label: {
                            HStack {
                                Text("🧠")
                                Text("今日のダンプがまだだよ")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(AppColors.ember)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.ember.opacity(0.1)))
                        }
                        .padding(.horizontal)
                    }

                    // #4 運動プライミング（格上げ）
                    if hasExerciseTrigger && !todayTasks.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("🏃 まず5分だけ動こう")
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("ドーパミンを補給してから集中する")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Text("脳科学的根拠あり ⚡️")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.ember.opacity(0.8))
                            }
                            Text("ストレッチ・散歩・階段・ジャンプなんでもOK")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)

                            if exerciseTimerRunning {
                                // タイマー表示
                                let remaining = max(0, 300 - exerciseTimer)
                                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppColors.success)

                                if exerciseTimer >= 300 {
                                    VStack(spacing: 6) {
                                        Text("🧠⚡️ ドーパミン補給完了！")
                                            .font(.caption.bold())
                                            .foregroundColor(AppColors.success)
                                        Button {
                                            stopExerciseTimer()
                                            selectedTask = todayTasks.first
                                        } label: {
                                            Text("🔥 着火する")
                                                .font(.subheadline.bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(12)
                                                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.fire))
                                                .foregroundColor(.white)
                                        }
                                    }
                                } else {
                                    Button {
                                        stopExerciseTimer()
                                        selectedTask = todayTasks.first
                                    } label: {
                                        Text("もう十分！着火する")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            } else {
                                Button {
                                    exerciseTimer = 0
                                    exerciseTimerRunning = true
                                    exerciseTimerObj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                                        exerciseTimer += 1
                                        if exerciseTimer >= 300 { stopExerciseTimer() }
                                    }
                                } label: {
                                    Text("5分タイマー開始 🏃")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.success))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.success.opacity(0.1)))
                        .padding(.horizontal)
                    }

                    if todayTasks.isEmpty && completedToday.isEmpty {
                        // 空状態
                        VStack(spacing: 16) {
                            Text("🔥")
                                .font(.system(size: 64))
                            Text("今日やることを決めよう")
                                .font(.title2.bold())
                                .foregroundColor(AppColors.textPrimary)
                            Text("ブレインダンプで書き出して\n3つに絞ろう")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button {
                                switchToTab = 0
                            } label: {
                                HStack {
                                    Text("🧠")
                                    Text("ダンプを始める")
                                        .font(.headline)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.fire))
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 60)
                    } else {
                        // 今日のタスクカード
                        ForEach(Array(todayTasks.enumerated()), id: \.element.persistentModelID) { index, task in
                            Button {
                                selectedTask = task
                            } label: {
                                if index == 0 {
                                    // 次の1つを大きく表示
                                    VStack(spacing: 8) {
                                        Text(task.icon).font(.system(size: 48))
                                        Text(task.name)
                                            .font(.title2.bold())
                                            .foregroundColor(AppColors.textPrimary)
                                        if let step = task.firstStep, !step.isEmpty {
                                            Text("最初の一歩: \(step)")
                                                .font(.caption)
                                                .foregroundColor(AppColors.ember)
                                        }
                                        Text("タップして着火 🔥")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.fire)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(24)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.fire.opacity(0.1)))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.fire.opacity(0.3), lineWidth: 1))
                                } else {
                                    if !hasSingleTaskTrigger {
                                        TaskCard(task: task, index: index)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(task)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    task.isCompleted = true
                                    task.completedAt = Date()
                                } label: {
                                    Label("完了", systemImage: "checkmark")
                                }
                                .tint(AppColors.success)
                            }
                            .contextMenu {
                                Button { editName = task.name; editingTask = task } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                if index > 0 {
                                    Button { moveToTop(task) } label: {
                                        Label("一番上に移動", systemImage: "arrow.up.to.line")
                                    }
                                    Button { reorder(task, direction: -1) } label: {
                                        Label("上に移動", systemImage: "arrow.up")
                                    }
                                }
                                if index < todayTasks.count - 1 {
                                    Button { reorder(task, direction: 1) } label: {
                                        Label("下に移動", systemImage: "arrow.down")
                                    }
                                }
                                Button(role: .destructive) { context.delete(task) } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                        .padding(.horizontal)

                        if hasSingleTaskTrigger && todayTasks.count > 1 {
                            Text("他に\(todayTasks.count - 1)つ待ってるよ")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal)
                        }

                        // 完了済み
                        ForEach(completedToday) { task in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.success)
                                Text(task.icon)
                                Text(task.name)
                                    .strikethrough()
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }

                        // 全完了
                        if todayTasks.isEmpty && !completedToday.isEmpty {
                            VStack(spacing: 12) {
                                Text("🎉")
                                    .font(.system(size: 64))
                                Text("ALL CLEAR!")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(AppColors.fire)
                                Text("今日のタスク全部終わった！")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.top, 32)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .onDisappear { stopExerciseTimer() }
            .fullScreenCover(item: $selectedTask) { task in
                IgniteView(task: task)
            }
            .alert("タスク名を編集", isPresented: Binding(get: { editingTask != nil }, set: { if !$0 { editingTask = nil } })) {
                TextField("タスク名", text: $editName)
                Button("保存") {
                    if let t = editingTask, !editName.isEmpty {
                        t.name = editName
                        t.icon = Task.autoIcon(for: editName)
                    }
                    editingTask = nil
                }
                Button("キャンセル", role: .cancel) { editingTask = nil }
            }
    }
    private func stopExerciseTimer() {
        exerciseTimerRunning = false
        exerciseTimerObj?.invalidate()
        exerciseTimerObj = nil
    }

    private func reorder(_ task: Task, direction: Int) {
        var tasks = todayTasks
        guard let idx = tasks.firstIndex(where: { $0 === task }) else { return }
        let newIdx = idx + direction
        guard tasks.indices.contains(newIdx) else { return }
        tasks.swapAt(idx, newIdx)
        for (i, t) in tasks.enumerated() { t.todayOrder = i }
    }

    private func moveToTop(_ task: Task) {
        var tasks = todayTasks
        guard let idx = tasks.firstIndex(where: { $0 === task }), idx > 0 else { return }
        let t = tasks.remove(at: idx)
        tasks.insert(t, at: 0)
        for (i, t) in tasks.enumerated() { t.todayOrder = i }
    }
}

struct TaskCard: View {
    @Environment(\.modelContext) private var context
    let task: Task
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            Text("\(index + 1)")
                .font(.title.bold())
                .foregroundColor(AppColors.fire)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.icon)
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }
                if let step = task.firstStep, !step.isEmpty {
                    Text("→ \(step)")
                        .font(.caption)
                        .foregroundColor(AppColors.ember)
                }
                Text("タップして着火 🔥")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button {
                withAnimation {
                    task.isCompleted = true
                    task.completedAt = Date()
                }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(AppColors.success.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .card()
    }
}
