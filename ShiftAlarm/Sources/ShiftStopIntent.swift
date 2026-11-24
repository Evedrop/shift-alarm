import AppIntents
import Foundation

/// 挂在 AlarmKit 的「停止」按钮上：
/// 你按下停止的那一刻，它会在锁屏 / 灵动岛上把今天这一班留下来。
struct ShiftStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "停止并显示今天班次"

    @Parameter(title: "班次日期")
    var shiftDate: String

    init() {}

    init(shiftDate: String) {
        self.shiftDate = shiftDate
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let store = PlanStore.shared
            LiveActivityManager.shared.sync(plan: store.plan)
        }
        return .result()
    }
}
