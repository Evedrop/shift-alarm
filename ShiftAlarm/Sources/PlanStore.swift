import Foundation
import SwiftUI

/// 全 App 唯一的数据源。用一个 Codable 的 Plan 存在 UserDefaults 里，
/// 改任何字段都会自动落盘。以后要接 iCloud 再换成 SwiftData 也只需要替换这个类。
@MainActor
final class PlanStore: ObservableObject {
    @Published var plan: Plan {
        didSet { persist() }
    }

    private static let storageKey = "shiftAlarm.plan.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(Plan.self, from: data) {
            plan = decoded
        } else {
            plan = .standard
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: 变更入口

    func apply(preset: Preset) {
        plan.pattern = preset.pattern
        plan.crews = preset.crews
        if plan.myCrew >= preset.crews { plan.myCrew = 0 }
        plan.overrides = [:]
        plan.alarmOff = [:]
    }

    func setOverride(_ date: Date, kind: ShiftKind) {
        let key = CalendarX.isoKey(date)
        if kind == plan.baseShift(on: date, crew: plan.myCrew) {
            plan.overrides.removeValue(forKey: key)
        } else {
            plan.overrides[key] = kind
        }
    }

    func clearOverride(_ date: Date) {
        plan.overrides.removeValue(forKey: CalendarX.isoKey(date))
    }

    func toggleAlarm(_ date: Date) {
        let key = CalendarX.isoKey(date)
        if plan.alarmOff[key] == true {
            plan.alarmOff.removeValue(forKey: key)
        } else {
            plan.alarmOff[key] = true
        }
    }

    func isAlarmOn(_ date: Date) -> Bool {
        plan.alarmDate(on: date) != nil
    }

    func renameCrew(_ index: Int, to name: String) {
        guard index < plan.crewNames.count else { return }
        plan.crewNames[index] = name
    }

    func shiftBinding(_ kind: ShiftKind) -> Binding<ShiftDef> {
        Binding(
            get: { self.plan.shiftDef(kind) },
            set: { newValue in
                if let index = self.plan.shifts.firstIndex(where: { $0.kind == kind }) {
                    self.plan.shifts[index] = newValue
                }
            }
        )
    }

    func updateShift(_ def: ShiftDef) {
        if let index = plan.shifts.firstIndex(where: { $0.kind == def.kind }) {
            plan.shifts[index] = def
        }
    }

    /// 改完循环天数 / 预设后，班组数必须能整除循环长度，否则退回单人排班
    func normalizeCrews() {
        if plan.crews > 1 {
            if plan.pattern.isEmpty || plan.pattern.count % plan.crews != 0 {
                plan.crews = 1
                plan.myCrew = 0
            }
        }
        if plan.myCrew >= plan.crews { plan.myCrew = 0 }
    }

    func refreshFromQuickStart(on date: Date, kind: ShiftKind, preset: Preset? = nil) {
        if let preset { apply(preset: preset) }
        let key = CalendarX.isoKey(date)
        if let anchor = plan.alignedAnchor(for: date, kind: kind) {
            plan.anchor = anchor
            plan.overrides.removeValue(forKey: key)
        } else {
            // 这套规律里没有这个班次（比如做二休二里没有夜班）→ 那天单独改
            plan.overrides[key] = kind
        }
    }

    func resetAll() {
        plan = .standard
    }

    /// 预览用：把已排入系统的闹钟全部撤掉（改需求/调试时用）
    func clearBooked() {
        plan.booked = [:]
    }
}
