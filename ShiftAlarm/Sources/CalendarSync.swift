import EventKit
import Foundation

struct CalendarChoice: Identifiable, Hashable {
    let id: String
    let title: String
}

/// 把班表写进「你自己选的」那个日历，不新建日历。
/// 只清理本 App 之前写进去的事件，绝不动你手工建的日程。
@MainActor
final class CalendarSync: ObservableObject {
    static let shared = CalendarSync()

    @Published private(set) var available: [CalendarChoice] = []
    @Published private(set) var status = "还没同步过"
    @Published private(set) var isSyncing = false

    /// 目标日历（记在本地，下次自动沿用）
    @Published var selectedID: String? {
        didSet { UserDefaults.standard.set(selectedID, forKey: Self.targetKey) }
    }

    private let store = EKEventStore()
    private static let targetKey = "shiftAlarm.calendarTarget"
    private static let idsKey = "shiftAlarm.calendarEventIDs"
    private let marker = "由「班表闹钟」自动生成"

    private init() {
        selectedID = UserDefaults.standard.string(forKey: Self.targetKey)
    }

    // MARK: 准备：授权 + 列出可写日历

    func prepare() async {
        guard await ensureAccess() else {
            status = "没有日历权限：去「设置 › 班表闹钟 › 日历」打开"
            return
        }
        reloadCalendars()
        if available.isEmpty {
            status = "系统里没有可写入的日历"
        } else if selectedID == nil {
            status = "选一个要写入的日历"
        }
    }

    func reloadCalendars() {
        guard EKEventStore.authorizationStatus(for: .event) != .notDetermined else { return }
        let calendars = store.calendars(for: .event).filter { $0.allowsContentModifications }
        available = calendars.map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title) }
        if selectedID == nil || !available.contains(where: { $0.id == selectedID }) {
            selectedID = pickDefault(from: calendars)?.calendarIdentifier
        }
    }

    // MARK: 写入

    func sync(plan: Plan, days: Int = 30) async {
        isSyncing = true
        defer { isSyncing = false }

        guard await ensureAccess() else {
            status = "没有日历权限：去「设置 › 班表闹钟 › 日历」打开"
            return
        }
        reloadCalendars()
        guard let id = selectedID, let calendar = store.calendar(withIdentifier: id) else {
            status = "先选一个要写入的日历"
            return
        }

        let from = CalendarX.startOfDay(Date())
        let to = CalendarX.addDays(from, days)

        // 1) 只删自己写过的：先按记录的 id，再按 notes 标记兜底
        for eventID in (UserDefaults.standard.stringArray(forKey: Self.idsKey) ?? []) {
            if let old = store.event(withIdentifier: eventID) {
                try? store.remove(old, span: .thisEvent, commit: false)
            }
        }
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let predicate = store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
            for old in store.events(matching: predicate) where (old.notes ?? "").hasPrefix(marker) {
                try? store.remove(old, span: .thisEvent, commit: false)
            }
        }

        // 2) 写新的
        var written = 0
        var newIDs: [String] = []
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
            event.notes = "\(marker)（提前 \(def.leadMinutes) 分钟提醒）"
            event.availability = .busy
            // 掉签兜底：日历提醒由系统日历进程投递，App 过期也照响。
            // 免费 Apple ID 只剩 7 天时，这条就是唯一还能叫醒你的东西。
            if def.leadMinutes > 0 {
                event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(def.leadMinutes) * 60))
            }

            do {
                try store.save(event, span: .thisEvent, commit: false)
                written += 1
                if let identifier = event.eventIdentifier { newIDs.append(identifier) }
            } catch {
                // 单条失败不影响其它
            }
        }

        try? store.commit()
        UserDefaults.standard.set(newIDs, forKey: Self.idsKey)
        status = "已写入 \(written) 个班次到「\(calendar.title)」，每个都带提前提醒（未来 \(days) 天）"
    }

    // MARK: 内部

    private func pickDefault(from calendars: [EKCalendar]) -> EKCalendar? {
        if let matched = calendars.first(where: { $0.title.contains("排班") || $0.title.contains("班表") }) {
            return matched
        }
        if let def = store.defaultCalendarForNewEvents, def.allowsContentModifications {
            return def
        }
        return calendars.first
    }

    private func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        case .notDetermined:
            // 优先要完整权限（才能列出日历并清理自己写过的），用户只给「仅添加」也能用
            do {
                _ = try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
            let after = EKEventStore.authorizationStatus(for: .event)
            return after == .fullAccess || after == .writeOnly
        default:
            return false
        }
    }
}
