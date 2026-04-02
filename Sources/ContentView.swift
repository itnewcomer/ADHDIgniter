import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var setupDone = false

    var body: some View {
        if setupDone || profiles.first?.setupCompleted == true {
            MainTabView()
                .preferredColorScheme(.dark)
        } else {
            SetupView(onComplete: { setupDone = true })
                .preferredColorScheme(.dark)
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Task> { $0.todayOrder != nil && !$0.isCompleted }) private var todayTasks: [Task]
    @Query(filter: #Predicate<Task> { !$0.isCompleted }) private var allActiveTasks: [Task]
    @State private var selectedTab = 2
    @State private var initialTabSet = false
    @State private var overdueTasks: [Task] = []
    @State private var showOverdueReview = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: BrainDumpView(switchToTab: $selectedTab)
                case 1: TimeHorizonView()
                case 2: TodayView(switchToTab: $selectedTab)
                case 3: InsightView()
                case 4: SettingsView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // カスタムタブバー
            HStack {
                tabButton("🧠", "ダンプ", 0)
                tabButton("📅", "プラン", 1)
                tabButton("🔥", "今日", 2)
                tabButton("📊", "分析", 3)
                tabButton("⚙️", "設定", 4)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(AppColors.cardBackground)
        }
        .background(AppColors.background)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            resetIfNewDay()
            if !initialTabSet {
                initialTabSet = true
                let overdue = findOverdueTasks()
                if !overdue.isEmpty {
                    overdueTasks = overdue
                    showOverdueReview = true
                } else if todayTasks.isEmpty {
                    selectedTab = 0
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resetIfNewDay() }
        }
        .sheet(isPresented: $showOverdueReview) {
            OverdueReviewView(tasks: overdueTasks) {
                showOverdueReview = false
                if todayTasks.isEmpty { selectedTab = 0 }
            }
        }
    }

    private func resetIfNewDay() {
        let key = "lastResetDate"
        let today = Calendar.current.startOfDay(for: Date()).description
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        // 昨日の未完了タスクを今週に戻す
        for task in todayTasks {
            task.todayOrder = nil
            if task.timeHorizon == .today {
                task.timeHorizon = .week
            }
        }

        // 今日の曜日に配置されたタスクを今日タスクに昇格
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        var order = 0
        for task in allActiveTasks where task.timeHorizon == .week && task.assignedWeekday != nil {
            if task.assignedWeekday == todayWeekday {
                // 今日の曜日 → 今日タスクに昇格
                task.timeHorizon = .today
                task.todayOrder = order
                task.assignedWeekday = nil
                order += 1
            } else if isPastWeekday(task.assignedWeekday!, today: todayWeekday) {
                // 過去の曜日 → 未配置に戻す（振り分け待ちに表示される）
                task.assignedWeekday = nil
            }
        }
    }

    private func isPastWeekday(_ weekday: Int, today: Int) -> Bool {
        // 今日から7日間のリストに含まれないなら過去
        let futureWeekdays = (0..<7).map { ((today - 1 + $0) % 7) + 1 }
        return !futureWeekdays.contains(weekday)
    }

    private func findOverdueTasks() -> [Task] {
        let cal = Calendar.current
        let now = Date()
        return allActiveTasks.filter { task in
            // dueDateが過ぎてる
            if let due = task.dueDate, due < now { return true }
            // 今週タスクだけど今週の月曜より前に作られた（1週間以上放置）
            if task.timeHorizon == .week,
               let weekAgo = cal.date(byAdding: .day, value: -7, to: now),
               task.createdAt < weekAgo { return true }
            // 今月タスクだけど先月以前に作られた
            if task.timeHorizon == .month,
               let monthAgo = cal.date(byAdding: .month, value: -1, to: now),
               task.createdAt < monthAgo { return true }
            return false
        }
    }

    private func tabButton(_ icon: String, _ label: String, _ index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 22))
                Text(label).font(.system(size: 10, weight: selectedTab == index ? .bold : .regular))
            }
            .foregroundColor(selectedTab == index ? AppColors.fire : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overdue Review

struct OverdueReviewView: View {
    let tasks: [Task]
    let onDone: () -> Void
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 24) {
            if currentIndex < tasks.count {
                let task = tasks[currentIndex]

                Text("\(currentIndex + 1) / \(tasks.count)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("📋")
                    .font(.system(size: 48))
                Text("このタスク、どうする？")
                    .font(.title2.bold())
                    .foregroundColor(AppColors.textPrimary)
                Text("計画が崩れるのは普通のこと。\n責めなくていいよ。")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("\(task.icon) \(task.name)")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBackground))

                if let due = task.dueDate {
                    Text("期限: \(due.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(AppColors.distracted)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button("🔥 今日やる") {
                        task.timeHorizon = .today
                        task.todayOrder = currentIndex
                        next()
                    }
                    .buttonStyle(FlowButtonStyle(color: AppColors.fire))

                    Button("📅 今週に入れ直す") {
                        task.timeHorizon = .week
                        task.assignedWeekday = nil
                        next()
                    }
                    .buttonStyle(FlowButtonStyle(color: AppColors.week))

                    Button("📦 いつかやるに移動") {
                        task.timeHorizon = .someday
                        next()
                    }
                    .buttonStyle(FlowButtonStyle(color: AppColors.someday))

                    Button("🗑 もうやらない") {
                        task.isCompleted = true
                        task.completedAt = Date()
                        next()
                    }
                    .buttonStyle(FlowButtonStyle(color: AppColors.textSecondary))
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    Text("✅")
                        .font(.system(size: 64))
                    Text("整理完了！")
                        .font(.title.bold())
                        .foregroundColor(AppColors.textPrimary)
                    Text("スッキリしたね")
                        .foregroundColor(AppColors.textSecondary)

                    Button("始めよう 🔥") { onDone() }
                        .font(.headline)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.fire))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
    }

    private func next() { currentIndex += 1 }
}
