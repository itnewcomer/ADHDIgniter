import SwiftUI
import SwiftData

struct TimeHorizonSortView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let items: [BrainDumpItem]
    var onComplete: ((Int) -> Void)? = nil  // タブ切り替えコールバック
    @State private var currentIndex = 0
    @State private var todayCount = 0
    @State private var snapshot: [BrainDumpItem] = []
    @State private var firstStep = ""
    @Query(filter: #Predicate<Task> { $0.todayOrder != nil && !$0.isCompleted })
    private var existingTodayTasks: [Task]
    @Query private var allTasks: [Task]

    var displayItems: [BrainDumpItem] {
        snapshot.isEmpty ? items : snapshot
    }

    // 既存タスクとの重複チェック
    private func findDuplicate(for text: String) -> Task? {
        let lower = text.lowercased()
        return allTasks.first { !$0.isCompleted && ($0.name.lowercased().contains(lower) || lower.contains($0.name.lowercased())) }
    }

    var body: some View {
        VStack(spacing: 24) {
            if currentIndex < displayItems.count {
                let item = displayItems[currentIndex]

                // 進捗
                Text("\(currentIndex + 1) / \(displayItems.count)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                ProgressView(value: Double(currentIndex), total: Double(displayItems.count))
                    .tint(AppColors.fire)
                    .padding(.horizontal)

                Spacer()

                // アイテム表示
                Text(item.text)
                    .font(.title2.bold())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("いつやる？")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                // 最初の一歩
                VStack(alignment: .leading, spacing: 4) {
                    Text("最初の一歩は？（任意）")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    TextField("例: まずファイルを開く", text: $firstStep)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground))
                        .foregroundColor(AppColors.textPrimary)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)

                // 重複チェック
                if let dup = findDuplicate(for: item.text) {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundColor(AppColors.warning)
                        Text("「\(dup.name)」がもうリストにあるよ")
                            .font(.caption)
                            .foregroundColor(AppColors.warning)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.warning.opacity(0.1)))
                    .padding(.horizontal)

                    Button {
                        item.convertedToTask = true
                        currentIndex += 1
                    } label: {
                        Text("スキップ（既にある）")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.warning.opacity(0.15)))
                            .foregroundColor(AppColors.warning)
                    }
                    .padding(.horizontal)
                }

                // 時間軸ボタン
                VStack(spacing: 12) {
                    ForEach(TimeHorizon.allCases, id: \.self) { horizon in
                        Button {
                            assign(item: item, horizon: horizon)
                        } label: {
                            HStack {
                                Image(systemName: horizon.icon)
                                Text(horizon.label)
                                Spacer()
                                if horizon == .today {
                                    Text("\(todayCount)/3")
                                        .font(.caption)
                                        .foregroundColor(todayCount >= 3 ? AppColors.distracted : AppColors.textSecondary)
                                }
                            }
                            .font(.headline)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorFor(horizon).opacity(0.15))
                            )
                            .foregroundColor(colorFor(horizon))
                        }
                    }

                    Button {
                        // スキップ（後で決める）
                        currentIndex += 1
                    } label: {
                        Text("後で決める")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)

                Spacer()
            } else {
                // 完了
                VStack(spacing: 16) {
                    Text("✅")
                        .font(.system(size: 64))
                    Text("振り分け完了！")
                        .font(.title.bold())
                        .foregroundColor(AppColors.textPrimary)
                    Text("今日やること: \(todayCount)つ")
                        .font(.headline)
                        .foregroundColor(AppColors.fire)

                    Button("📅 全体を確認する") {
                        onComplete?(1) // プランタブ
                        dismiss()
                    }
                    .font(.headline)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.week))
                    .foregroundColor(.white)

                    Button("🔥 今日のタスクへ") {
                        onComplete?(2) // 今日タブ
                        dismiss()
                    }
                    .font(.headline)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.fire))
                    .foregroundColor(.white)
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if snapshot.isEmpty {
                snapshot = Array(items)
                todayCount = existingTodayTasks.count
            }
        }
    }

    private func assign(item: BrainDumpItem, horizon: TimeHorizon) {
        item.timeHorizon = horizon
        item.convertedToTask = true

        let task = Task(name: item.text, timeHorizon: horizon)
        if !firstStep.isEmpty { task.firstStep = firstStep }
        if horizon == .today {
            task.todayOrder = todayCount
            todayCount += 1
        }
        context.insert(task)

        firstStep = ""
        currentIndex += 1
    }

    private func colorFor(_ horizon: TimeHorizon) -> Color {
        switch horizon {
        case .today: AppColors.today
        case .week: AppColors.week
        case .month: AppColors.month
        case .quarter: AppColors.quarter
        case .someday: AppColors.someday
        }
    }
}
