import Foundation

// MARK: - 班次日型

/// 五班三倒里的五种日型。`rest` 不排闹钟。
enum ShiftKind: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case night
    case study
    case rest

    var id: String { rawValue }
    var isRest: Bool { self == .rest }
}

// MARK: - 班次定义

struct ShiftDef: Codable, Hashable, Identifiable {
    var kind: ShiftKind
    var name: String
    var short: String
    var startMinute: Int      // 从 00:00 起的分钟数
    var hours: Int
    var leadMinutes: Int      // 提前多久响
    var colorHex: String
    var alarmEnabled: Bool

    var id: String { kind.rawValue }
    var isRest: Bool { kind == .rest }
    var endMinute: Int { (startMinute + hours * 60) % 1440 }

    var timeRangeLabel: String {
        guard !isRest else { return "—" }
        return "\(CalendarX.timeLabel(startMinute)) – \(CalendarX.timeLabel(endMinute))"
    }
}

// MARK: - 待响的闹钟

/// 一个「已排进系统」的闹钟（一次性）。
struct PlannedAlarm: Identifiable, Hashable {
    let id: String          // "2026-11-25|morning|0730" —— 含时间，改时间就会重排
    let fireDate: Date
    let shiftDate: Date
    let kind: ShiftKind
    let minutes: Int        // 响铃时刻，便于展示
    let dayOffset: Int      // -1 表示落在前一天晚上（夜班）
}

// MARK: - 排班方案

struct Plan: Codable, Equatable {
    var pattern: [ShiftKind]
    var anchor: Date              // 循环起始日（当天 0 点）
    var crews: Int                // 班组数，1 = 单人
    var myCrew: Int
    var crewNames: [String]
    var shifts: [ShiftDef]
    var masterOn: Bool
    var overrides: [String: ShiftKind]   // "yyyy-MM-dd" -> 手动改班
    var alarmOff: [String: Bool]         // "yyyy-MM-dd" -> 单日关闭
    var booked: [String: UUID]           // 已排入系统的闹钟 key -> AlarmKit id

    // MARK: 默认值

    static var standard: Plan {
        Plan(
            pattern: [.study, .morning, .morning, .afternoon, .afternoon,
                      .rest, .night, .night, .rest, .rest],
            anchor: CalendarX.startOfDay(Date()),
            crews: 5,
            myCrew: 0,
            crewNames: ["甲班", "乙班", "丙班", "丁班", "戊班", "己班", "庚班", "辛班"],
            shifts: [
                ShiftDef(kind: .morning, name: "早班", short: "早", startMinute: 8 * 60,
                         hours: 8, leadMinutes: 30, colorHex: "#FF9F0A", alarmEnabled: true),
                ShiftDef(kind: .afternoon, name: "中班", short: "中", startMinute: 16 * 60,
                         hours: 8, leadMinutes: 30, colorHex: "#0A84FF", alarmEnabled: true),
                ShiftDef(kind: .night, name: "夜班", short: "夜", startMinute: 0,
                         hours: 8, leadMinutes: 45, colorHex: "#BF5AF2", alarmEnabled: true),
                ShiftDef(kind: .study, name: "学习", short: "学", startMinute: 9 * 60,
                         hours: 8, leadMinutes: 30, colorHex: "#0E8A9E", alarmEnabled: true),
                ShiftDef(kind: .rest, name: "休息", short: "休", startMinute: 0,
                         hours: 0, leadMinutes: 0, colorHex: "#D1D1D6", alarmEnabled: false)
            ],
            masterOn: true,
            overrides: [:],
            alarmOff: [:],
            booked: [:]
        )
    }

    // MARK: 基础查询

    func shiftDef(_ kind: ShiftKind) -> ShiftDef {
        shifts.first { $0.kind == kind }
            ?? ShiftDef(kind: kind, name: "休息", short: "休", startMinute: 0, hours: 0,
                        leadMinutes: 0, colorHex: "#D1D1D6", alarmEnabled: false)
    }

    func crewName(_ index: Int) -> String {
        if index < crewNames.count, !crewNames[index].isEmpty { return crewNames[index] }
        return "第\(index + 1)班"
    }

    /// 班组错位步长：10 天 ÷ 5 班 = 2
    var crewStride: Int {
        guard crews > 1, pattern.count % crews == 0 else { return 0 }
        return pattern.count / crews
    }

    var patternName: String {
        if let hit = Presets.all.first(where: { $0.pattern == pattern && $0.crews == crews }) {
            return hit.name
        }
        return "自定义 \(pattern.count) 天循环"
    }

    // MARK: 排班

    /// 不考虑手动覆盖的原始排班
    func baseShift(on date: Date, crew: Int) -> ShiftKind {
        guard !pattern.isEmpty else { return .rest }
        let dayIndex = CalendarX.daysBetween(anchor, date) + crew * crewStride
        let length = pattern.count
        let index = ((dayIndex % length) + length) % length
        return pattern[index]
    }

    /// 当前视角的排班（手动覆盖只作用于「我」的班组）
    func shift(on date: Date, crew: Int? = nil) -> ShiftKind {
        let target = crew ?? myCrew
        let key = CalendarX.isoKey(date)
        if target == myCrew, let override = overrides[key] { return override }
        return baseShift(on: date, crew: target)
    }

    func isOverridden(_ date: Date) -> Bool {
        overrides[CalendarX.isoKey(date)] != nil
    }

    /// 让某一天正好是某个班次所需的循环起点（不改当前 anchor，只算出来）
    func alignedAnchor(for date: Date, kind: ShiftKind, crew: Int? = nil) -> Date? {
        guard !pattern.isEmpty, let index = pattern.firstIndex(of: kind) else { return nil }
        let target = crew ?? myCrew
        let length = pattern.count
        let offset = ((index - target * crewStride) % length + length) % length
        return CalendarX.addDays(CalendarX.startOfDay(date), -offset)
    }

    /// 用指定循环起点试算某天的班（不动真实数据，给预览用）
    func shiftPreview(on date: Date, anchor: Date, crew: Int? = nil) -> ShiftKind {
        guard !pattern.isEmpty else { return .rest }
        let target = crew ?? myCrew
        let n = CalendarX.daysBetween(anchor, date) + target * crewStride
        let i = ((n % pattern.count) + pattern.count) % pattern.count
        return pattern[i]
    }

    // MARK: 闹钟时间

    /// 某天班次对应的响铃时刻（可能落在前一天晚上）
    func alarmDate(on date: Date) -> Date? {
        guard masterOn else { return nil }
        let key = CalendarX.isoKey(date)
        guard alarmOff[key] != true else { return nil }
        let kind = shift(on: date)
        let def = shiftDef(kind)
        guard !def.isRest, def.alarmEnabled else { return nil }

        let raw = def.startMinute - def.leadMinutes
        let dayShift = raw < 0 ? -1 : 0
        let minutes = (raw + 1440) % 1440
        let base = CalendarX.addDays(CalendarX.startOfDay(date), dayShift)
        return CalendarX.cal.date(byAdding: .minute, value: minutes, to: base)
    }

    /// 未来 n 天要排进系统的闹钟（已排序，且都会晚于 now）
    func upcomingAlarms(from now: Date = Date(), days: Int = 14) -> [PlannedAlarm] {
        guard masterOn else { return [] }
        let today = CalendarX.startOfDay(now)
        var result: [PlannedAlarm] = []

        // 从昨天开始扫，避免漏掉「今晚 23:15 响、对应明天夜班」这类跨天闹钟
        for offset in -1...days {
            let date = CalendarX.addDays(today, offset)
            guard let fire = alarmDate(on: date), fire > now else { continue }
            let kind = shift(on: date)
            let def = shiftDef(kind)
            let minutes = CalendarX.minuteOfDay(fire)
            let dayOffset = CalendarX.daysBetween(date, fire)
            let key = "\(CalendarX.isoKey(date))|\(kind.rawValue)|\(CalendarX.timeLabel(minutes))"
            result.append(PlannedAlarm(id: key, fireDate: fire, shiftDate: date,
                                       kind: kind, minutes: minutes, dayOffset: dayOffset))
        }

        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(days))
    }

    /// 影响排班/闹钟的字段指纹；用它触发重新排闹钟，避免 booked 变化导致的循环
    var signature: String {
        let p = pattern.map(\.rawValue).joined(separator: ",")
        let s = shifts.map {
            "\($0.kind.rawValue):\($0.startMinute):\($0.hours):\($0.leadMinutes):\($0.alarmEnabled)"
        }.joined(separator: ";")
        let o = overrides.keys.sorted().map { "\($0)=\(overrides[$0]!.rawValue)" }.joined(separator: ",")
        let off = alarmOff.keys.sorted().map { "\($0)=\(alarmOff[$0]!)" }.joined(separator: ",")
        return "\(p)#\(anchor.timeIntervalSince1970)#\(crews)#\(myCrew)#\(s)#\(o)#\(off)#\(masterOn)"
    }
}

// MARK: - 预设

struct Preset: Identifiable, Hashable {
    var name: String
    var pattern: [ShiftKind]
    var crews: Int
    var id: String { name }
    var workDays: Int { pattern.filter { !$0.isRest }.count }
}

enum Presets {
    static let all: [Preset] = [
        Preset(name: "五班三倒",
               pattern: [.study, .morning, .morning, .afternoon, .afternoon,
                         .rest, .night, .night, .rest, .rest],
               crews: 5),
        Preset(name: "做二休二", pattern: [.morning, .morning, .rest, .rest], crews: 1),
        Preset(name: "做一休一", pattern: [.morning, .rest], crews: 1),
        Preset(name: "做五休二",
               pattern: [.morning, .morning, .morning, .morning, .morning, .rest, .rest], crews: 1),
        Preset(name: "四班三倒",
               pattern: [.morning, .morning, .afternoon, .afternoon,
                         .night, .night, .rest, .rest], crews: 4),
        Preset(name: "白夜休休", pattern: [.morning, .night, .rest, .rest], crews: 1),
        Preset(name: "三班轮转",
               pattern: [.morning, .morning, .afternoon, .afternoon,
                         .night, .night, .rest], crews: 1)
    ]
}

// MARK: - 日期工具

enum CalendarX {
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2          // 周一为一周第一天
        c.timeZone = .current
        return c
    }()

    static func startOfDay(_ date: Date) -> Date { cal.startOfDay(for: date) }

    static func addDays(_ date: Date, _ n: Int) -> Date {
        cal.date(byAdding: .day, value: n, to: date) ?? date
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    /// 0 = 周一 … 6 = 周日
    static func weekdayIndex(_ date: Date) -> Int {
        (cal.component(.weekday, from: date) + 5) % 7
    }

    static func startOfMonth(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    static func startOfWeek(_ date: Date) -> Date {
        addDays(startOfDay(date), -weekdayIndex(date))
    }

    static func addMonths(_ date: Date, _ n: Int) -> Date {
        cal.date(byAdding: .month, value: n, to: startOfMonth(date)) ?? date
    }

    static func daysInMonth(_ date: Date) -> Int {
        cal.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func minuteOfDay(_ date: Date) -> Int {
        cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    static func timeLabel(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func isoKey(_ date: Date) -> String { isoFormatter.string(from: date) }

    static func date(fromISO string: String) -> Date? { isoFormatter.date(from: string) }

    private static let mdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    static func md(_ date: Date) -> String { mdFormatter.string(from: date) }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    static func monthTitle(_ date: Date) -> String { monthFormatter.string(from: date) }

    static func week(_ date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let idx = cal.component(.weekday, from: date) - 1
        return names[max(0, min(6, idx))]
    }

    static let weekShort = ["一", "二", "三", "四", "五", "六", "日"]

    /// 「今天 / 明天 / 后天 / 11月27日」
    static func relativeDay(_ date: Date, from now: Date = Date()) -> String {
        switch daysBetween(now, date) {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default: return md(date)
        }
    }
}
