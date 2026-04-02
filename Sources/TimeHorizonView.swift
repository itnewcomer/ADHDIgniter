import SwiftUI
import SwiftData

struct TimeHorizonView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Task.order) private var allTasks: [Task]
    @Query private var profiles: [UserProfile]
    @State private var selectedTask: Task?
    @State private var isReassigning = false

    @State private var editingTask: Task?
    @State private var editName = ""

    private var calendarApp: CalendarApp? { profiles.first?.calendarApp }

    private var todayTasks: [Task] {
        allTasks.filter { $0.todayOrder != nil && !$0.isCompleted }
            .sorted { ($0.todayOrder ?? 0) < ($1.todayOrder ?? 0) }
    }

    private var unplacedWeekTasks: [Task] {
        allTasks.filter { $0.timeHorizon == .week && !$0.isCompleted && $0.assignedWeekday == nil }
    }

    private var monthTasks: [Task] {
        allTasks.filter { $0.timeHorizon == .month && !$0.isCompleted }
    }

    private var unplacedMonthTasks: [Task] {
        monthTasks.filter { $0.assignedWeekOfMonth == nil }
    }

    private func monthTasksFor(week: Int) -> [Task] {
        monthTasks.filter { $0.assignedWeekOfMonth == week }
    }

    private var currentWeekOfMonth: Int {
        Calendar.current.component(.weekOfMonth, from: Date())
    }

    private var weeksInMonth: Int {
        let cal = Calendar.current
        return cal.range(of: .weekOfMonth, in: .month, for: Date())?.count ?? 4
    }

    private func weekDateLabel(week: Int) -> String {
        let cal = Calendar.current
        let weeksAhead = week - currentWeekOfMonth
        guard let weekStart = cal.date(byAdding: .weekOfYear, value: weeksAhead, to: cal.startOfDay(for: Date())) else { return "" }
        let weekday = cal.component(.weekday, from: weekStart)
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
        guard let monday = cal.date(byAdding: .day, value: daysToMonday, to: weekStart) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return fmt.string(from: monday) + "〜"
    }

    private func weekLabel(week: Int) -> String {
        let diff = week - currentWeekOfMonth
        switch diff {
        case 1: return "来週"
        case 2: return "再来週"
        default: return weekDateLabel(week: week)
        }
    }

    private var futureWeeks: [Int] {
        let start = currentWeekOfMonth + 1
        return (start...(start + 3)).map { $0 }
    }

    private var quarterTasks: [Task] {
        allTasks.filter { $0.timeHorizon == .quarter && !$0.isCompleted }
    }

    private var somedayTasks: [Task] {
        allTasks.filter { $0.timeHorizon == .someday && !$0.isCompleted }
    }

    private func tasksFor(weekday: Int) -> [Task] {
        var tasks = allTasks.filter { $0.timeHorizon == .week && !$0.isCompleted && $0.assignedWeekday == weekday }
        // 今日の曜日なら今日タスクも表示
        if weekday == todayWeekday {
            tasks += todayTasks
        }
        return tasks
    }

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }

    private var weekdayLabels: [(Int, String)] {
        let names = ["", "日", "月", "火", "水", "木", "金", "土"]
        let today = todayWeekday
        // 今日から7日分
        return (0..<7).map { offset in
            let wd = ((today - 1 + offset) % 7) + 1
            return (wd, names[wd])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 今日
                sectionHeader("🔥 今日", color: AppColors.fire)
                if todayTasks.isEmpty {
                    emptyHint("ブレインダンプで書き出そう")
                } else {
                    ForEach(todayTasks, id: \.name) { task in
                        taskRow(task)
                    }
                }

                Divider().background(AppColors.textSecondary.opacity(0.3))

                // 未配置（今週）
                if !unplacedWeekTasks.isEmpty {
                    sectionHeader("📦 今週やること（タップして配置）", color: AppColors.week)
                    ForEach(unplacedWeekTasks, id: \.name) { task in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTask = selectedTask?.name == task.name ? nil : task
                                isReassigning = false
                            }
                        } label: {
                            HStack {
                                Text(task.icon)
                                Text(task.name)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selectedTask?.name == task.name {
                                    Text("↓ 曜日を選んでね")
                                        .font(.caption)
                                        .foregroundColor(AppColors.ember)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTask?.name == task.name ? AppColors.week.opacity(0.2) : AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedTask?.name == task.name ? AppColors.week : .clear, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // 曜日バー
                    if selectedTask != nil && !isReassigning {
                        weekdayBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Divider().background(AppColors.textSecondary.opacity(0.3))
                }

                // 今週（配置済み）
                sectionHeader("📆 今週", color: AppColors.week)
                weeklyTimeline

                // 再配置用の曜日バー
                if isReassigning && selectedTask != nil {
                    weekdayBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 今月
                if !monthTasks.isEmpty {
                    Divider().background(AppColors.textSecondary.opacity(0.3))
                    sectionHeader("📅 今月", color: AppColors.month)

                    // 未配置タスク
                    if !unplacedMonthTasks.isEmpty {
                        ForEach(unplacedMonthTasks, id: \.name) { task in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTask = selectedTask?.name == task.name ? nil : task
                                    isReassigning = false
                                }
                            } label: {
                                HStack {
                                    Text(task.icon)
                                    Text(task.name).foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if selectedTask?.name == task.name {
                                        Text("↓ 週を選んでね")
                                            .font(.caption)
                                            .foregroundColor(AppColors.month)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTask?.name == task.name ? AppColors.month.opacity(0.2) : AppColors.cardBackground))
                            }
                        }
                        .padding(.horizontal)

                        // 週選択バー
                        if selectedTask != nil && selectedTask.map({ $0.timeHorizon == .month && $0.assignedWeekOfMonth == nil }) == true {
                            monthWeekBar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // 週番号タイムライン
                    monthlyTimeline

                    // 再配置用の週バー
                    if isReassigning && selectedTask != nil && selectedTask.map({ $0.timeHorizon == .month }) == true {
                        monthWeekBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // 3ヶ月
                if !quarterTasks.isEmpty {
                    Divider().background(AppColors.textSecondary.opacity(0.3))
                    sectionHeader("🏔 3ヶ月", color: AppColors.quarter)
                    ForEach(quarterTasks, id: \.name) { task in
                        taskRow(task)
                    }
                }

                // いつかやる
                if !somedayTasks.isEmpty {
                    Divider().background(AppColors.textSecondary.opacity(0.3))
                    sectionHeader("📦 いつかやる", color: AppColors.textSecondary)
                    ForEach(somedayTasks, id: \.name) { task in
                        taskRow(task)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
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

    // MARK: - Components

    private func sectionHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(color)
            .padding(.horizontal)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal)
    }

    private func taskRow(_ task: Task) -> some View {
        HStack(spacing: 8) {
            Text(task.icon)
            Text(task.name)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            if let app = calendarApp {
                Button {
                    if let url = app.url(title: task.name, date: task.dueDate) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("📅")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contextMenu {
            Button { editName = task.name; editingTask = task } label: {
                Label("編集", systemImage: "pencil")
            }
            Menu("移動") {
                ForEach(TimeHorizon.allCases, id: \.self) { h in
                    if h != task.timeHorizon {
                        Button("\(h.label)へ") {
                            task.timeHorizon = h
                            task.assignedWeekday = nil
                            task.todayOrder = nil
                        }
                    }
                }
            }
            Button(role: .destructive) { context.delete(task) } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - Weekday Bar

    private var weekdayBar: some View {
        HStack(spacing: 8) {
            ForEach(weekdayLabels, id: \.0) { weekday, name in
                Button {
                    placeTask(on: weekday)
                } label: {
                    VStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 14, weight: weekday == todayWeekday ? .bold : .regular))
                        Circle()
                            .fill(weekday == todayWeekday ? AppColors.fire : AppColors.week.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.cardBackground)
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private func placeTask(on weekday: Int) {
        guard let task = selectedTask else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if weekday == todayWeekday {
                // 今日に配置 → 今日タスクに昇格
                task.timeHorizon = .today
                task.todayOrder = todayTasks.count
                task.assignedWeekday = nil
            } else {
                task.timeHorizon = .week
                task.todayOrder = nil
                task.assignedWeekday = weekday
            }
            selectedTask = nil
            isReassigning = false
        }
    }

    // MARK: - Weekly Timeline

    private var weeklyTimeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(weekdayLabels, id: \.0) { weekday, name in
                let tasks = tasksFor(weekday: weekday)
                let isToday = weekday == todayWeekday

                HStack(alignment: .top, spacing: 12) {
                    // 曜日ラベル
                    Text(name)
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundColor(isToday ? AppColors.fire : AppColors.textSecondary)
                        .frame(width: 24)

                    // ドット
                    Circle()
                        .fill(isToday ? AppColors.fire : AppColors.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    // タスク
                    if tasks.isEmpty {
                        Text("─")
                            .foregroundColor(AppColors.textSecondary.opacity(0.3))
                            .padding(.vertical, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(tasks, id: \.name) { task in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        if selectedTask?.name == task.name {
                                            selectedTask = nil
                                        } else {
                                            selectedTask = task
                                            isReassigning = true
                                        }
                                    }
                                } label: {
                                    Text("\(task.icon) \(task.name)")
                                        .font(.subheadline)
                                        .foregroundColor(isToday ? AppColors.textPrimary : AppColors.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedTask?.name == task.name ? AppColors.week.opacity(0.2) : .clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editName = task.name; editingTask = task } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    Button {
                                        task.assignedWeekday = nil
                                        task.todayOrder = nil
                                        task.timeHorizon = .month
                                    } label: {
                                        Label("1ヶ月以内に送る", systemImage: "calendar.badge.clock")
                                    }
                                    Button {
                                        task.assignedWeekday = nil
                                        task.todayOrder = nil
                                        task.timeHorizon = .someday
                                    } label: {
                                        Label("いつかやるに送る", systemImage: "tray")
                                    }
                                    Button(role: .destructive) {
                                        task.todayOrder = nil
                                        context.delete(task)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal)
                .background(
                    isToday ? AppColors.fire.opacity(0.05) : .clear
                )
            }
        }
    }

    // MARK: - Monthly Week Bar

    private var monthWeekBar: some View {
        HStack(spacing: 8) {
            ForEach(futureWeeks, id: \.self) { week in
                Button {
                    placeMonthTask(on: week)
                } label: {
                    VStack(spacing: 2) {
                        Text(weekLabel(week: week))
                            .font(.system(size: 11, weight: week == currentWeekOfMonth ? .bold : .regular))
                        Text(weekDateLabel(week: week))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground))
                }
            }
        }
        .padding(.horizontal)
    }

    private func placeMonthTask(on week: Int) {
        guard let task = selectedTask else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            task.assignedWeekOfMonth = week
            selectedTask = nil
            isReassigning = false
        }
    }

    // MARK: - Monthly Timeline

    private var monthlyTimeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(futureWeeks, id: \.self) { week in
                let tasks = monthTasksFor(week: week)
                let isCurrent = week == currentWeekOfMonth

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 1) {
                        Text(weekLabel(week: week))
                            .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? AppColors.fire : AppColors.textSecondary)
                        Text(weekDateLabel(week: week))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(width: 50)

                    Circle()
                        .fill(isCurrent ? AppColors.fire : AppColors.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    if tasks.isEmpty {
                        Text("─")
                            .foregroundColor(AppColors.textSecondary.opacity(0.3))
                            .padding(.vertical, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(tasks, id: \.name) { task in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        if selectedTask?.name == task.name {
                                            selectedTask = nil
                                            isReassigning = false
                                        } else {
                                            selectedTask = task
                                            isReassigning = true
                                        }
                                    }
                                } label: {
                                    Text("\(task.icon) \(task.name)")
                                        .font(.subheadline)
                                        .foregroundColor(isCurrent ? AppColors.textPrimary : AppColors.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedTask?.name == task.name ? AppColors.month.opacity(0.2) : .clear))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editName = task.name; editingTask = task } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    Menu("移動") {
                                        ForEach(TimeHorizon.allCases, id: \.self) { h in
                                            if h != task.timeHorizon {
                                                Button("\(h.label)へ") {
                                                    task.timeHorizon = h
                                                    task.assignedWeekOfMonth = nil
                                                    task.assignedWeekday = nil
                                                    task.todayOrder = nil
                                                }
                                            }
                                        }
                                    }
                                    Button(role: .destructive) { context.delete(task) } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal)
                .background(isCurrent ? AppColors.fire.opacity(0.05) : .clear)
            }
        }
    }
}
