import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var phase: String // "initial", "flowing"
    }

    var taskName: String
    var taskIcon: String
    var declaration: String
    var startedAt: Date
}
