import Foundation
import SwiftUI
import AlarmKit

// ============================================================================
//  AlarmKit 适配层 —— 整个工程只有这一个文件直接依赖 AlarmKit。
//
//  这里的签名已对照 Apple 官方文档（iOS 26）核对过：
//    · AlarmManager.AlarmConfiguration(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)
//    · AlarmManager.schedule(id:configuration:) -> Alarm          id 是 UUID
//    · AlarmManager.AuthorizationState (.authorized / .denied / .notDetermined)
//    · Alarm.Schedule.fixed(Date)                                  ← 一次性、精确到时刻
//    · AlarmPresentation.Alert(title:stopButton:secondaryButton:secondaryButtonBehavior:)
//    · AlarmAttributes(presentation:metadata:tintColor:)
//
//  两个刻意的取舍：
//    1. 用 .fixed(Date) 而不是 .relative(Time)：轮班要把未来 14 天排成 14 个一次性闹钟，
//       相对时间只会落到「今天/明天的那个点」，日期会全错。
//    2. 不传 countdownDuration（也就是没有「稍后提醒」）：Apple 明确说只要用了倒计时状态，
//       就必须带 Widget Extension，否则系统可能直接忽略闹钟。v0.1 先保证一定响。
//       以后要加稍后提醒：加一个 Widget Extension + countdownDuration + .repeatButton。
//
//  真机要求：iOS 26、Info.plist 里有 NSAlarmKitUsageDescription（project.yml 已配）。
//  模拟器不会真的响铃，必须真机。
// ============================================================================

enum AlarmAuthState {
    case unknown
    case granted
    case denied
}

/// 随闹钟一起存进系统的附加信息，锁屏 / 灵动岛上可以读它。
struct ShiftAlarmMetadata: AlarmMetadata {
    var shiftName: String
    var shiftDate: String
}

@MainActor
final class AlarmService: ObservableObject {
    static let shared = AlarmService()

    @Published private(set) var auth: AlarmAuthState = .unknown
    @Published private(set) var lastError: String?

    private init() {}

    private var manager: AlarmManager { AlarmManager.shared }

    // MARK: 授权

    func refreshAuth() async {
        let state = await manager.authorizationState
        auth = Self.map(state)
    }

    func requestAuth() async {
        do {
            let state = try await manager.requestAuthorization()
            auth = Self.map(state)
            if auth != .granted {
                lastError = "系统没有授权闹钟，去「设置 › 班表闹钟 › 闹钟」里打开"
            } else {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> AlarmAuthState {
        switch state {
        case .authorized: return .granted
        case .denied: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    // MARK: 试验闹钟（用来确认真机上系统闹钟能不能响）

    @Published private(set) var testAlarmID: UUID?
    @Published private(set) var testFireDate: Date?

    /// 排一个 N 秒后响的一次性闹钟。不写进 plan.booked，所以不会被排班同步撤掉。
    func scheduleTestAlarm(in seconds: TimeInterval) async {
        if auth != .granted { await requestAuth() }
        guard auth == .granted else {
            lastError = "还没拿到系统闹钟权限，先去「设置 › 班表闹钟 › 闹钟」里打开"
            return
        }
        await cancelTestAlarm()

        let id = UUID()
        let fire = Date().addingTimeInterval(seconds)
        do {
            try await scheduleRaw(
                id: id,
                fire: fire,
                title: "试验闹钟 · \(Int(seconds)) 秒到了",
                tint: Color.brand
            )
            testAlarmID = id
            testFireDate = fire
            lastError = nil
            // 响过之后把按钮状态收回来
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((seconds + 15) * 1_000_000_000))
                await MainActor.run {
                    if self?.testAlarmID == id {
                        self?.testAlarmID = nil
                        self?.testFireDate = nil
                    }
                }
            }
        } catch {
            lastError = "试验闹钟排程失败：\(error.localizedDescription)"
        }
    }

    func cancelTestAlarm() async {
        if let id = testAlarmID {
            try? await manager.cancel(id: id)
        }
        testAlarmID = nil
        testFireDate = nil
    }

    // MARK: 把 Plan 里未来 14 天的闹钟同步进系统

    /// 返回新的「key -> AlarmKit id」映射，调用方写回 plan.booked。
    func sync(plan: Plan) async -> [String: UUID] {
        guard auth == .granted else { return plan.booked }

        let desired = plan.upcomingAlarms(days: 14)
        let desiredKeys = Set(desired.map(\.id))
        var result: [String: UUID] = [:]

        // 1. 撤掉不再需要的（改班、改时间、关总开关都会走到这里）
        for (key, id) in plan.booked where !desiredKeys.contains(key) {
            try? await manager.cancel(id: id)
        }

        // 2. 保留已有的，补排新增的
        for alarm in desired {
            if let existing = plan.booked[alarm.id] {
                result[alarm.id] = existing
                continue
            }
            let id = UUID()
            do {
                try await schedule(alarm: alarm, plan: plan, id: id)
                result[alarm.id] = id
            } catch {
                lastError = error.localizedDescription
            }
        }

        return result
    }

    func cancelAll(plan: Plan) async {
        for (_, id) in plan.booked {
            try? await manager.cancel(id: id)
        }
    }

    // MARK: 单条排程

    private func schedule(alarm: PlannedAlarm, plan: Plan, id: UUID) async throws {
        let def = plan.shiftDef(alarm.kind)
        try await scheduleRaw(
            id: id,
            fire: alarm.fireDate,
            title: "\(def.name) \(CalendarX.timeLabel(def.startMinute)) 开始",
            tint: Color(hex: def.colorHex)
        )
    }

    /// 所有闹钟都走这里：一个 fixed 时刻 + 一个停止按钮
    private func scheduleRaw(id: UUID, fire: Date, title: String, tint: Color) async throws {
        // iOS 26.1 才有无 stopButton 的新初始化方法；这里用 26.0 就有的旧方法（仅弃用警告），
        // 保证 iOS 26.0 的机器也能装
        let resource = LocalizedStringResource(stringLiteral: title)
        let stopButton = AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.fill")
        let alert = AlarmPresentation.Alert(
            title: resource,
            stopButton: stopButton,
            secondaryButton: nil,
            secondaryButtonBehavior: nil
        )

        // 显式写出泛型参数，避免推断失败
        let attributes = AlarmAttributes<ShiftAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: ShiftAlarmMetadata(shiftName: title,
                                         shiftDate: CalendarX.isoKey(fire)),
            tintColor: tint
        )

        let configuration = AlarmManager.AlarmConfiguration<ShiftAlarmMetadata>(
            countdownDuration: nil,
            schedule: .fixed(fire),
            attributes: attributes,
            // 按下「停止」的那一刻，把今天的班次留到锁屏 / 灵动岛上
            stopIntent: ShiftStopIntent(shiftDate: CalendarX.isoKey(fire)),
            secondaryIntent: nil,
            sound: .default
        )

        _ = try await manager.schedule(id: id, configuration: configuration)
    }
}
