import SwiftUI

@main
struct ShiftAlarmApp: App {
    @StateObject private var store = PlanStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Color.brand)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var service = AlarmService.shared

    var body: some View {
        TabView {
            CalendarTab()
                .tabItem { Label("排班", systemImage: "calendar") }
            CrewsTab()
                .tabItem { Label("班组", systemImage: "square.grid.2x2") }
            RulesTab()
                .tabItem { Label("规律", systemImage: "arrow.triangle.2.circlepath") }
            AlarmsTab()
                .tabItem { Label("闹钟", systemImage: "bell") }
        }
        .task {
            await service.refreshAuth()
            await syncAlarms()
        }
        // 只监听影响排班的字段，避免「写回 booked」再次触发同步
        .onChange(of: store.plan.signature) { _, _ in
            Task { await syncAlarms() }
        }
        // 回到前台时，顺手把「今天这一班」的锁屏/灵动岛提醒同步一下
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                LiveActivityManager.shared.sync(plan: store.plan)
            }
        }
        .onAppear {
            LiveActivityManager.shared.sync(plan: store.plan)
        }
    }

    private func syncAlarms() async {
        let booked = await service.sync(plan: store.plan)
        if booked != store.plan.booked {
            store.plan.booked = booked
        }
    }
}
