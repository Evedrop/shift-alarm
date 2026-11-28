import Combine
import Foundation
import UserNotifications

// MARK: - 读取安装包里的签名信息

/// 免费 Apple ID 签出来的 App 只有 7 天寿命，到期后图标变白、打不开，
/// AlarmKit 闹钟和本地通知会一起失效。这里读 `embedded.mobileprovision`
/// 把「还剩几天」算出来，逼着用户在掉签前去刷新一次。
enum SigningInfo {
    struct Profile {
        let name: String            // "iOS Team Provisioning Profile: com.example.ShiftAlarm"
        let teamName: String        // 团队 / 个人名
        let appID: String           // "XXXX.com.example.ShiftAlarm"
        let created: Date
        let expires: Date

        /// 这张描述文件本身的有效天数（免费证书是 7）
        var durationDays: Int {
            max(0, Int((expires.timeIntervalSince(created) / 86_400).rounded()))
        }

        var isFreeAccount: Bool { durationDays <= 8 }
    }

    static let shared: Profile? = load()

    // MARK: 解析

    private static func load() -> Profile? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let plistData = extractPlist(from: data)
        else { return nil }

        guard let raw = try? PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil),
              let plist = raw as? [String: Any]
        else { return nil }

        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        return Profile(
            name: plist["Name"] as? String ?? "—",
            teamName: plist["TeamName"] as? String ?? "—",
            appID: entitlements["application-identifier"] as? String ?? "—",
            created: plist["CreationDate"] as? Date ?? Date(),
            expires: plist["ExpirationDate"] as? Date ?? Date()
        )
    }

    /// .mobileprovision 是 CMS/PKCS#7 信封，里面夹着一段 XML plist，抠出来即可
    private static func extractPlist(from data: Data) -> Data? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8),
                                   in: start.lowerBound..<data.endIndex)
        else { return nil }
        return data[start.lowerBound..<end.upperBound]
    }

    // MARK: 剩余时间

    /// 还剩下多少小时（负数表示已经过期）
    static func hoursRemaining(now: Date = Date()) -> Double? {
        guard let p = shared else { return nil }
        return p.expires.timeIntervalSince(now) / 3_600
    }

    /// 还剩下多少个自然日
    static func daysRemaining(now: Date = Date()) -> Int? {
        guard let p = shared else { return nil }
        return CalendarX.daysBetween(now, p.expires)
    }

    static func expiryLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }
}

// MARK: - 掉签提醒

/// 在描述文件到期前，提前排两条本地通知。
/// 通知由系统投递，App 本身掉签后大概率仍会响 —— 这是最后一道保险。
@MainActor
final class SigningWatch: ObservableObject {
    static let shared = SigningWatch()

    /// 提前多少小时提醒（两条）
    private static let checkpoints: [Double] = [36, 6]
    private static let idPrefix = "shiftalarm.signing."

    @Published private(set) var enabled: Bool =
        UserDefaults.standard.bool(forKey: "shiftAlarm.signingReminder")
    @Published private(set) var status = ""

    private init() {}

    // MARK: 授权 + 排期

    func enable(now: Date = Date()) async {
        let granted = await requestAuth()
        guard granted else {
            status = "系统通知没开：去「设置 › 班表闹钟 › 通知」打开"
            return
        }
        UserDefaults.standard.set(true, forKey: "shiftAlarm.signingReminder")
        enabled = true
        await reschedule(now: now)
    }

    func reschedule(now: Date = Date()) async {
        guard let profile = SigningInfo.shared else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: Self.checkpoints.map { Self.idPrefix + String(Int($0)) }
        )
        guard enabled else { return }

        var scheduled: [String] = []
        for hours in Self.checkpoints {
            let fireDate = profile.expires.addingTimeInterval(-hours * 3_600)
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "班表闹钟 \(Int(hours)) 小时后掉签"
            content.body = "到期后 App 打不开、闹钟全停。打开 SideStore 刷新一次就好。"
            content.sound = .default

            let interval = max(5, fireDate.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + String(Int(hours)),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled.append(String(Int(hours)))
            } catch {
                // 单条排不上就跳过
            }
        }

        status = scheduled.isEmpty
            ? "已经在倒数里了（或剩余时间不足 6 小时，刷新后再来）"
            : "已排 \(scheduled.joined(separator: " / ")) 小时前各提醒一次"
    }

    private func requestAuth() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }
}
