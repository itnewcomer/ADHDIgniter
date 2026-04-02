import WidgetKit
import SwiftUI
import ActivityKit

@main
struct FocusLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FocusLiveActivity()
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // ロック画面 Live Activity
            HStack(spacing: 12) {
                Text("🔥")
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.attributes.taskIcon) \(context.attributes.taskName)")
                        .font(.headline)
                        .foregroundColor(.white)

                    if !context.attributes.declaration.isEmpty {
                        Text(context.attributes.declaration)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 経過時間（リアルタイム）
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(16)
            .background(Color(red: 0.14, green: 0.14, blue: 0.18))

        } dynamicIsland: { context in
            DynamicIsland {
                // 展開時
                DynamicIslandExpandedRegion(.leading) {
                    Text("🔥")
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.attributes.taskIcon) \(context.attributes.taskName)")
                            .font(.headline)
                        if !context.attributes.declaration.isEmpty {
                            Text("「\(context.attributes.declaration)」")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Text("🔥")
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
            } minimal: {
                Text("🔥")
            }
        }
    }
}
