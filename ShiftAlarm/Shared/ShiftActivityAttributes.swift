import Foundation
import ActivityKit

/// App 和 Widget 扩展共用：锁屏 / 灵动岛上显示的今天班次
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String        // 早班 08:00–16:00
        var shortName: String    // 早
        var colorHex: String     // #FF9F0A
        var statusText: String   // 进行中 · 还有 3 小时
        var endDate: Date
    }

    var shiftDate: String        // 2026-11-25
}
