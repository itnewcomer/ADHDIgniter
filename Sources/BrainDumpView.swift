import SwiftUI
import SwiftData

struct BrainDumpView: View {
    @Environment(\.modelContext) private var context
    @State private var rawText = ""
    @State private var showSort = false
    @State private var todayDump: BrainDump?
    @Binding var switchToTab: Int

    // 今日のダンプ済みアイテム
    @Query(filter: #Predicate<BrainDumpItem> { $0.convertedToTask == false },
           sort: \BrainDumpItem.dumpDate, order: .reverse)
    private var pendingItems: [BrainDumpItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 4) {
                        Text("🧠")
                            .font(.system(size: 48))
                        Text("頭の中を全部出そう")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.textPrimary)
                        Text("書き出すだけで脳が軽くなる")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 16)

                    // テキスト入力
                    TextEditor(text: $rawText)
                        .frame(minHeight: 200)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.cardBackground)
                        )
                        .foregroundColor(AppColors.textPrimary)
                        .overlay(alignment: .topLeading) {
                            if rawText.isEmpty {
                                Text("気になっていること、\n頭の隅に追いやっていること、\nやらなきゃいけないこと、\nなんでも全部書き出してみよう...\n\n書き出すだけで脳の負荷が下がることが\n研究でわかっているよ")
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.horizontal)

                    // 振り分けボタン
                    if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            saveDump()
                        } label: {
                            HStack {
                                Text("スッキリした！振り分ける")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.fire))
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                    }

                    // 未振り分けアイテム
                    if !pendingItems.isEmpty {
                        NavigationLink {
                            TimeHorizonSortView(items: pendingItems) { tab in
                                switchToTab = tab
                            }
                        } label: {
                            HStack {
                                Text("時間軸に振り分ける")
                                    .font(.headline)
                                Text("(\(pendingItems.count)件)")
                                    .font(.subheadline)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.ember))
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("振り分け待ち")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)

                            ForEach(pendingItems, id: \.text) { item in
                                HStack {
                                    Text("•")
                                    Text(item.text)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if let h = item.timeHorizon {
                                        Text(h.label)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(AppColors.fire.opacity(0.2)))
                                            .foregroundColor(AppColors.fire)
                                    }
                                }
                                .padding(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("ブレインダンプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func saveDump() {
        let dump = BrainDump(rawText: rawText)
        context.insert(dump)

        let lines = rawText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let item = BrainDumpItem(text: line)
            context.insert(item)
        }

        rawText = ""
    }
}
