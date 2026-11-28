import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlanStore
    @ObservedObject private var service = AlarmService.shared
    @ObservedObject private var calendar = CalendarSync.shared
    @ObservedObject private var watch = SigningWatch.shared
    @Environment(\.dismiss) private var dismiss

    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("排班") {
                    NavigationLink("班次时间与提前量") {
                        ShiftSettingsView()
                            .environmentObject(store)
                    }
                }

                Section("日历") {
                    if calendar.available.isEmpty {
                        Button("加载我手机里的日历") {
                            Task { await calendar.prepare() }
                        }
                    } else {
                        Picker("写入哪个日历", selection: Binding(
                            get: { calendar.selectedID ?? calendar.available.first?.id ?? "" },
                            set: { calendar.selectedID = $0 }
                        )) {
                            ForEach(calendar.available) { choice in
                                Text(choice.title).tag(choice.id)
                            }
                        }
                    }

                    Button {
                        Task { await calendar.sync(plan: store.plan) }
                    } label: {
                        HStack {
                            Text(calendar.isSyncing ? "正在写入…" : "写入未来 30 天班表")
                            Spacer()
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.brand)
                        }
                    }
                    .disabled(calendar.isSyncing)

                    Text(calendar.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("系统闹钟") {
                    HStack {
                        Text("权限")
                        Spacer()
                        Text(authText)
                            .foregroundStyle(.secondary)
                    }
                    Button("重新申请授权") {
                        Task { await service.requestAuth() }
                    }
                    if let error = service.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                signingSection

                Section("数据") {
                    HStack {
                        Text("已排入系统")
                        Spacer()
                        Text("\(store.plan.booked.count) 个")
                            .foregroundStyle(.secondary)
                    }
                    Button("清空已排闹钟记录", role: .destructive) {
                        store.clearBooked()
                    }
                    Button("恢复默认设置", role: .destructive) {
                        confirmReset = true
                    }
                }

                Section {
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("数据存在本机，换手机不会同步。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await calendar.prepare()
                await watch.reschedule()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("恢复默认设置？", isPresented: $confirmReset) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) { store.resetAll() }
            } message: {
                Text("会清掉自定义规律、班组名称和手动改班。")
            }
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "班表闹钟 v\(short) (\(build))"
    }

    // MARK: 签名

    @ViewBuilder
    private var signingSection: some View {
        Section("签名与续签") {
            if let profile = SigningInfo.shared {
                HStack {
                    Text("剩余")
                    Spacer()
                    Text(remainingText)
                        .fontWeight(.semibold)
                        .foregroundStyle(remainingColor)
                }
                HStack {
                    Text("到期时刻")
                    Spacer()
                    Text(SigningInfo.expiryLabel(profile.expires))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("有效期")
                    Spacer()
                    Text(profile.isFreeAccount
                         ? "\(profile.durationDays) 天（免费 Apple ID）"
                         : "\(profile.durationDays) 天")
                        .foregroundStyle(.secondary)
                }

                if watch.enabled {
                    Button("重新排掉签提醒") {
                        Task { await watch.reschedule() }
                    }
                } else {
                    Button("开启掉签提醒") {
                        Task { await watch.enable() }
                    }
                }

                if !watch.status.isEmpty {
                    Text(watch.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("到期后 App 会打不开，系统闹钟也跟着失效。用 SideStore 刷新一下就能续 7 天；想彻底不用管，就买 99 美元/年的开发者账号，有效期直接变 365 天。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("读不到 embedded.mobileprovision —— 说明这次不是用常规侧载器装的，算不出剩余天数。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var remainingText: String {
        guard let hours = SigningInfo.hoursRemaining() else { return "未知" }
        if hours <= 0 { return "已过期" }
        if hours < 48 { return String(format: "%.0f 小时", hours) }
        return "\(Int(hours / 24)) 天"
    }

    private var remainingColor: Color {
        guard let hours = SigningInfo.hoursRemaining() else { return Color.secondary }
        if hours <= 0 { return .red }
        if hours <= 48 { return .orange }
        return .green
    }

    private var authText: String {
        switch service.auth {
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        case .unknown: return "未授权"
        }
    }
}
