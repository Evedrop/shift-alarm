import SwiftUI

struct AlarmsTab: View {
    @EnvironmentObject private var store: PlanStore
    @ObservedObject private var service = AlarmService.shared

    private var plan: Plan { store.plan }
    private var upcoming: [PlannedAlarm] { plan.upcomingAlarms(days: 8) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    authCard
                    SectionHeader(title: "接下来的闹钟", trailing: "共 \(upcoming.count) 个")
                    listCard
                    Text("周期轮班不是「每周重复」，所以实现上把未来 14 天展开成一批一次性系统闹钟；增删班次或改时间后会自动重排。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Color.pageBackground)
            .navigationTitle("闹钟")
            .refreshable {
                await service.refreshAuth()
                let booked = await service.sync(plan: store.plan)
                store.plan.booked = booked
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("总开关")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { plan.masterOn },
                    set: { store.plan.masterOn = $0 }
                ))
                .labelsHidden()
                .tint(Color.brand)
            }

            if let next = upcoming.first {
                Text(CalendarX.timeLabel(next.minutes))
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(CalendarX.relativeDay(next.fireDate)) \(CalendarX.week(next.fireDate)) · \(plan.shiftDef(next.kind).name) \(CalendarX.timeLabel(plan.shiftDef(next.kind).startMinute)) 开始")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("--:--")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Text(plan.masterOn ? "未来 14 天没有需要响铃的班次" : "总开关已关闭，所有闹钟暂停")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack {
                Text("已排入系统 \(plan.booked.count) 个")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button {
                    Task {
                        let booked = await service.sync(plan: store.plan)
                        store.plan.booked = booked
                    }
                } label: {
                    Text("重新同步")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#FFB340"))
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: "#1B1F2E"), Color(hex: "#0C0E15")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.brand.opacity(0.4), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: 240)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var authCard: some View {
        HStack(spacing: 11) {
            Image(systemName: service.auth == .granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 19))
                .foregroundStyle(service.auth == .granted ? .green : Color.orange)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.restGray))

            VStack(alignment: .leading, spacing: 2) {
                Text("系统闹钟权限")
                    .font(.system(size: 13.5, weight: .semibold))
                Text(authDetail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(service.auth == .granted ? "管理" : "去授权") {
                Task { await service.requestAuth() }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(service.auth == .granted ? Color.restGray : Color.brand))
            .foregroundStyle(service.auth == .granted ? Color.primary : .white)
            .buttonStyle(.plain)
        }
        .card()
    }

    private var authDetail: String {
        switch service.auth {
        case .granted: return "已授权，静音与专注模式下也会响铃"
        case .denied: return "已拒绝，闹钟不会响；请到系统设置里打开"
        case .unknown: return "未授权，系统闹钟不会响铃"
        }
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            if upcoming.isEmpty {
                Text(plan.masterOn ? "暂无闹钟" : "总开关已关闭")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                ForEach(upcoming) { alarm in
                    AlarmRow(alarm: alarm,
                             def: plan.shiftDef(alarm.kind),
                             isOn: store.plan.alarmDate(on: alarm.shiftDate) != nil) {
                        store.toggleAlarm(alarm.shiftDate)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if alarm.id != upcoming.last?.id {
                        Divider()
                    }
                }
            }
        }
        .card(padding: 0)
    }
}

struct AlarmRow: View {
    let alarm: PlannedAlarm
    let def: ShiftDef
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(CalendarX.timeLabel(alarm.minutes))
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(CalendarX.md(alarm.fireDate)) \(CalendarX.week(alarm.fireDate))")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: def.colorHex))
                        .frame(width: 6, height: 6)
                    Text("\(def.name) \(def.timeRangeLabel)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isOn }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(.green)
        }
    }
}
