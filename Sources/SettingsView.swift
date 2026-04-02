import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @State private var newRewardName = ""
    @State private var newRewardCost = 5
    @State private var editingRewardIndex: Int? = nil
    @State private var editRewardName = ""
    @State private var editRewardCost = 5

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                // トリガー設定
                Section("集中トリガー") {
                    ForEach(TriggerType.allCases) { trigger in
                        let isEnabled = profile?.enabledTriggers.contains(trigger) ?? false
                        Button {
                            toggleTrigger(trigger)
                        } label: {
                            HStack {
                                Text(trigger.icon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trigger.label)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(trigger.hint)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if isEnabled {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.fire)
                                }
                            }
                        }
                        .listRowBackground(AppColors.cardBackground)
                    }
                }

                // 音楽設定
                Section("音楽") {
                    ForEach(MusicSource.allCases, id: \.self) { source in
                        Button {
                            profile?.preferredMusicSource = source
                        } label: {
                            HStack {
                                Text(source.label)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if profile?.preferredMusicSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.fire)
                                }
                            }
                        }
                        .listRowBackground(AppColors.cardBackground)
                    }

                    if profile?.preferredMusicSource == .spotify {
                        TextField("SpotifyプレイリストURL", text: Binding(
                            get: { profile?.spotifyPlaylistURL ?? "" },
                            set: { profile?.spotifyPlaylistURL = $0 }
                        ))
                        .foregroundColor(AppColors.textPrimary)
                        .listRowBackground(AppColors.cardBackground)
                    }

                    if profile?.preferredMusicSource == .appleMusic {
                        TextField("Apple MusicプレイリストURL", text: Binding(
                            get: { profile?.appleMusicPlaylistURL ?? "" },
                            set: { profile?.appleMusicPlaylistURL = $0 }
                        ))
                        .foregroundColor(AppColors.textPrimary)
                        .listRowBackground(AppColors.cardBackground)
                    }
                }

                // カレンダー連携
                Section("カレンダー") {
                    ForEach(CalendarApp.allCases, id: \.self) { app in
                        Button {
                            profile?.calendarApp = profile?.calendarApp == app ? nil : app
                        } label: {
                            HStack {
                                Text(app.icon)
                                Text(app.label)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if profile?.calendarApp == app {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.fire)
                                }
                            }
                        }
                        .listRowBackground(AppColors.cardBackground)
                    }
                }

                // データ
                Section("朝のリマインダー") {
                    Picker("通知時間", selection: Binding(
                        get: { profile?.morningReminderHour ?? 8 },
                        set: {
                            profile?.morningReminderHour = $0
                            ADHDIgniterApp.scheduleMorningReminder(hour: $0)
                        }
                    )) {
                        ForEach(5...11, id: \.self) { h in
                            Text("\(h):00").tag(h)
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .listRowBackground(AppColors.cardBackground)
                }

                Section("ご褒美") {
                    ForEach(Array((profile?.rewards ?? []).enumerated()), id: \.offset) { i, reward in
                        Button {
                            editingRewardIndex = i
                            editRewardName = reward.0
                            editRewardCost = reward.1
                        } label: {
                            HStack {
                                Text(reward.0).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text("\(reward.1) pt").foregroundColor(AppColors.fire)
                                Image(systemName: "pencil").font(.caption).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .listRowBackground(AppColors.cardBackground)
                    }
                    .onDelete { offsets in
                        guard let profile else { return }
                        var list = profile.rewards
                        list.remove(atOffsets: offsets)
                        profile.rewards = list
                    }

                    HStack {
                        TextField("ご褒美の名前", text: $newRewardName)
                            .foregroundColor(AppColors.textPrimary)
                        Stepper("\(newRewardCost)pt", value: $newRewardCost, in: 1...100)
                            .foregroundColor(AppColors.fire)
                        Button {
                            guard !newRewardName.isEmpty, let profile else { return }
                            var list = profile.rewards
                            list.append((newRewardName, newRewardCost))
                            profile.rewards = list
                            newRewardName = ""
                            newRewardCost = 5
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(AppColors.fire)
                        }
                    }
                    .listRowBackground(AppColors.cardBackground)
                }
                .alert("ご褒美を編集", isPresented: Binding(get: { editingRewardIndex != nil }, set: { if !$0 { editingRewardIndex = nil } })) {
                    TextField("名前", text: $editRewardName)
                    TextField("ポイント", value: $editRewardCost, format: .number)
                    Button("保存") {
                        if let i = editingRewardIndex, let profile, !editRewardName.isEmpty {
                            var list = profile.rewards
                            list[i] = (editRewardName, editRewardCost)
                            profile.rewards = list
                        }
                        editingRewardIndex = nil
                    }
                    Button("キャンセル", role: .cancel) { editingRewardIndex = nil }
                }

                Section("データ") {
                    Button("データリセット", role: .destructive) {
                        resetData()
                    }
                    .listRowBackground(AppColors.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func toggleTrigger(_ trigger: TriggerType) {
        guard let profile else { return }
        if let idx = profile.enabledTriggers.firstIndex(of: trigger) {
            profile.enabledTriggers.remove(at: idx)
        } else {
            profile.enabledTriggers.append(trigger)
        }
    }

    private func resetData() {
        try? context.delete(model: Task.self)
        try? context.delete(model: BrainDump.self)
        try? context.delete(model: BrainDumpItem.self)
        try? context.delete(model: FocusSession.self)
        try? context.delete(model: CheckIn.self)
    }
}
