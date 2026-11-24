import ActivityKit
import Foundation

/// 管理「今天的班次」这条实时活动：锁屏卡片 + 灵动岛。
/// 触发点有两个：闹钟停止（ShiftStopIntent）和 App 回到前台。
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var current: Activity<ShiftActivityAttributes>?
    private init() {}

    /// 按今天（或指定时间点）的班次开启 / 更新提醒
    func sync(plan: Plan, now: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let today = CalendarX.startOfDay(now)
        let kind = plan.shift(on: today)
        let def = plan.shiftDef(kind)

        guard !def.isRest else {
            Task { await endActivity() }
            return
        }

        let start = CalendarX.cal.date(byAdding: .minute, value: def.startMinute, to: today) ?? today
        let shiftEnd = CalendarX.cal.date(byAdding: .hour, value: def.hours, to: start) ?? start

        // 只在「班次开始前 3 小时 ~ 下班」这段有意义的时间里显示，
        // 深夜打开 App 不会再冒出「已下班」的卡片
        let windowStart = start.addingTimeInterval(-3 * 3600)
        guard now >= windowStart, now < shiftEnd else {
            Task { await endActivity() }
            return
        }

        let state = ShiftActivityAttributes.ContentState(
            title: "\(def.name) \(CalendarX.timeLabel(def.startMinute))–\(CalendarX.timeLabel(def.startMinute + def.hours * 60))",
            shortName: def.short,
            colorHex: def.colorHex,
            statusText: statusText(now: now, start: start, end: shiftEnd),
            endDate: shiftEnd
        )
        // 下班之后系统会自动收掉这条活动
        let content = ActivityContent(state: state, staleDate: shiftEnd)

        Task { await upsert(today: today, content: content) }
    }

    func endActivity() async {
        if let current {
            await current.end(nil, dismissalPolicy: .immediate)
        }
        current = nil
    }

    // MARK: 内部

    private func upsert(today: Date, content: ActivityContent<ShiftActivityAttributes.ContentState>) async {
        if let current {
            await current.update(content)
            return
        }
        do {
            current = try Activity<ShiftActivityAttributes>.request(
                attributes: ShiftActivityAttributes(shiftDate: CalendarX.isoKey(today)),
                content: content,
                pushType: nil
            )
        } catch {
            current = nil
        }
    }

    private func statusText(now: Date, start: Date, end: Date) -> String {
        if now < start {
            let minutes = Int(start.timeIntervalSince(now) / 60)
            if minutes >= 60 { return "还有 \(minutes / 60) 小时 \(minutes % 60) 分上班" }
            return "还有 \(minutes) 分钟上班"
        }
        if now < end {
            let minutes = Int(end.timeIntervalSince(now) / 60)
            if minutes >= 60 { return "进行中 · 还有 \(minutes / 60) 小时下班" }
            return "进行中 · 还有 \(minutes) 分钟下班"
        }
        return "已下班，早点休息"
    }
}
