import SwiftUI

@main
struct ShiftAlarmApp: App {
    @StateObject private var store = PlanStore()

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
    }

    private func syncAlarms() async {
        let booked = await service.sync(plan: store.plan)
        if booked != store.plan.booked {
            store.plan.booked = booked
        }
    }
}
