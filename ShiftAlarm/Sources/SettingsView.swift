import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlanStore
    @ObservedObject private var service = AlarmService.shared
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
                    Text("班表闹钟 v0.1")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("数据存在本机，换手机不会同步。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
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

    private var authText: String {
        switch service.auth {
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        case .unknown: return "未授权"
        }
    }
}
