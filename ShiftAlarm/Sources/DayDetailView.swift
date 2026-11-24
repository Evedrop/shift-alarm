import SwiftUI

/// 点某一天后弹出的详情：可以在这里直接换日期、改单日班次、开关当天闹钟、恢复规律。
struct DayDetailView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss

    @State private var current: Date

    init(date: Date) {
        _current = State(initialValue: CalendarX.startOfDay(date))
    }

    private var plan: Plan { store.plan }
    private var kind: ShiftKind { plan.shift(on: current) }
    private var def: ShiftDef { plan.shiftDef(kind) }
    private var alarm: Date? { plan.alarmDate(on: current) }
    private var overridden: Bool { plan.isOverridden(current) }

    private var subtitle: String {
        let crew = plan.crews > 1 ? "\(plan.crewName(plan.myCrew)) · " : ""
        if overridden { return crew + "已手动调整，不跟随规律" }
        return crew + "按「\(plan.patternName)」自动排班"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    dateHeader

                    Picker("班次", selection: Binding(
                        get: { store.plan.shift(on: current) },
                        set: { store.setOverride(current, kind: $0) }
                    )) {
                        ForEach(ShiftKind.allCases) { item in
                            Text(store.plan.shiftDef(item).short).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    detailCard
                    alarmCard

                    if overridden {
                        Button("恢复为循环规律") {
                            store.clearOverride(current)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    }

                    Button("完成") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Color.pageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: 日期头（可以改日期）

    private var dateHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    current = CalendarX.addDays(current, -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.restGray))
                }
                .buttonStyle(.plain)

                DatePicker("", selection: $current, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                Text(CalendarX.week(current))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                Button {
                    current = CalendarX.addDays(current, 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.restGray))
                }
                .buttonStyle(.plain)
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: 信息卡

    private var detailCard: some View {
        VStack(spacing: 0) {
            row("班次时间", def.isRest ? "—" : def.timeRangeLabel)
            Divider()
            row("闹钟时间", alarm.map { CalendarX.timeLabel(CalendarX.minuteOfDay($0)) } ?? "—")
            Divider()
            row("提前提醒", def.isRest ? "—" : "\(def.leadMinutes) 分钟")
        }
        .card(padding: 0)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14)
        .frame(height: 46)
    }

    private var alarmCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("该日闹钟").font(.system(size: 14, weight: .semibold))
                Text(alarmHint).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.plan.alarmDate(on: current) != nil },
                set: { _ in store.toggleAlarm(current) }
            ))
            .labelsHidden()
            .disabled(def.isRest || !plan.masterOn)
        }
        .card()
        .opacity(def.isRest || !plan.masterOn ? 0.55 : 1)
    }

    private var alarmHint: String {
        if def.isRest { return "休息日不设闹钟" }
        if !plan.masterOn { return "总开关已关闭" }
        return alarm == nil ? "已关闭" : "会覆盖静音，全屏响铃"
    }
}
