import SwiftUI
import SwiftData
import UserNotifications

@main
struct ADHDIgniterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { requestNotificationPermission() }
        }
        .modelContainer(for: [
            Task.self,
            BrainDump.self,
            BrainDumpItem.self,
            FocusSession.self,
            CheckIn.self,
            UserProfile.self,
        ])
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleMorningReminder(hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning-dump"])

        let content = UNMutableNotificationContent()
        content.title = "🧠 頭スッキリさせよう"
        content.body = "今日もブレインダンプで脳の掃除から始めよう"
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: "morning-dump", content: content, trigger: trigger))
    }
}
