import EventKit
import Foundation

/// 把班表写进系统日历（写完就能在「日历」App 里看到，也能给家人共享）。
@MainActor
final class CalendarSync: ObservableObject {
    static let shared = CalendarSync()

    @Published private(set) var status = "还没同步过"
    @Published private(set) var isSyncing = false

    private let store = EKEventStore()
    private let calendarTitle = "班表闹钟"

    func sync(plan: Plan, days: Int = 30) async {
        isSyncing = true
        defer { isSyncing = false }

        guard await ensureAccess() else {
            status = "没有日历权限：去「设置 › 班表闹钟 › 日历」打开"
            return
        }
        guard let calendar = ensureCalendar() else {
            status = "创建日历失败（可能是系统日历源不可用）"
            return
        }

        let from = CalendarX.startOfDay(Date())
        let to = CalendarX.addDays(from, days)

        // 只清理我们自己那个日历里的事件
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
        for event in store.events(matching: predicate) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }

        var written = 0
        for offset in 0..<days {
            let day = CalendarX.addDays(from, offset)
            let def = plan.shiftDef(plan.shift(on: day))
            guard !def.isRest else { continue }

            let start = CalendarX.cal.date(byAdding: .minute, value: def.startMinute, to: day) ?? day
            let end = CalendarX.cal.date(byAdding: .hour, value: def.hours, to: start) ?? start

            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = "\(def.name) \(CalendarX.timeLabel(def.startMinute))–\(CalendarX.timeLabel(def.startMinute + def.hours * 60))"
            event.startDate = start
            event.endDate = end
            event.notes = "由「班表闹钟」自动生成"
            event.availability = .busy

            do {
                try store.save(event, span: .thisEvent, commit: false)
                written += 1
            } catch {
                // 单条失败不影响其它
            }
        }

        try? store.commit()
        status = "已写入 \(written) 个班次（未来 \(days) 天）"
    }

    // MARK: 权限与日历

    private func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return true
        case .notDetermined:
            do {
                return try await store.requestWriteOnlyAccessToEvents()
            } catch {
                return false
            }
        default:
            return false
        }
    }

    private func ensureCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local }
        guard calendar.source != nil else { return nil }
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }
}
