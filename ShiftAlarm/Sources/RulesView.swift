import SwiftUI

struct RulesTab: View {
    @EnvironmentObject private var store: PlanStore
    @State private var showQuickStart = false

    private var plan: Plan { store.plan }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    quickStartCard
                    patternCard
                    SectionHeader(title: "预设规律", trailing: "点一下立即套用")
                    presetsGrid
                    SectionHeader(title: "编辑循环", trailing: "每天一个班次")
                    cycleCard
                    SectionHeader(title: "循环起点")
                    anchorCard
                    SectionHeader(title: "班次时间")
                    shiftLink
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Color.pageBackground)
            .navigationTitle("排班规律")
            .sheet(isPresented: $showQuickStart) {
                QuickStartView()
                    .environmentObject(store)
            }
        }
    }

    // MARK: 快速排班入口

    private var quickStartCard: some View {
        Button {
            showQuickStart = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.brand.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("快速排班")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text("点一天 → 选那天的班 → 后面自动往下排")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: 当前规律

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.patternName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("\(plan.pattern.count) 天一轮")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(plan.pattern.indices), id: \.self) { index in
                        ShiftTag(def: plan.shiftDef(plan.pattern[index]))
                    }
                }
            }

            HStack {
                Text("起始日")
                    .foregroundStyle(.secondary)
                Text("\(CalendarX.md(plan.anchor)) \(CalendarX.week(plan.anchor))")
                    .fontWeight(.semibold)
                Spacer()
                Text("出勤 \(plan.pattern.filter { !$0.isRest }.count) / \(plan.pattern.count) 天")
            }
            .font(.system(size: 12))

            if plan.crews > 1 {
                HStack {
                    Text("\(plan.crews) 个班组 · 错开 \(plan.crewStride) 天")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .card()
    }

    // MARK: 预设

    private var presetsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                  spacing: 9) {
            ForEach(Presets.all) { preset in
                PresetCard(preset: preset,
                           selected: isSelected(preset),
                           plan: plan) {
                    store.apply(preset: preset)
                    store.normalizeCrews()
                }
            }
        }
    }

    private func isSelected(_ preset: Preset) -> Bool {
        preset.pattern == plan.pattern && preset.crews == plan.crews
    }

    // MARK: 编辑循环

    private var cycleCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.pattern.indices), id: \.self) { index in
                HStack(spacing: 10) {
                    Text("第 \(index + 1) 天")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 62, alignment: .leading)

                    Menu {
                        ForEach(ShiftKind.allCases) { kind in
                            Button(plan.shiftDef(kind).name) {
                                store.plan.pattern[index] = kind
                                store.normalizeCrews()
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            ShiftTag(def: plan.shiftDef(plan.pattern[index]))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if plan.pattern.count > 1 {
                        Button {
                            store.plan.pattern.remove(at: index)
                            store.normalizeCrews()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)

                if index < plan.pattern.count - 1 {
                    Divider()
                }
            }

            Button {
                store.plan.pattern.append(.rest)
                store.normalizeCrews()
            } label: {
                Label("添加一天", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.restGray)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .card()
    }

    // MARK: 起始日

    private var anchorCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("从这天开始循环")
                Spacer()
                DatePicker("", selection: Binding(
                    get: { store.plan.anchor },
                    set: { store.plan.anchor = CalendarX.startOfDay($0) }
                ), displayedComponents: .date)
                .labelsHidden()
            }
            .font(.system(size: 14))
            .padding(.vertical, 4)
        }
        .card()
    }

    private var shiftLink: some View {
        NavigationLink {
            ShiftSettingsView()
                .environmentObject(store)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("早 / 中 / 夜 / 学习的开始时间")
                        .font(.system(size: 14, weight: .medium))
                    Text("时长、提前几分钟响铃")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预设卡片

struct PresetCard: View {
    let preset: Preset
    let selected: Bool
    let plan: Plan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                    if preset.crews > 1 {
                        Text("\(preset.crews) 班组")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(selected ? Color.brand : Color.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.restGray))
                    }
                }

                HStack(spacing: 2.5) {
                    ForEach(Array(preset.pattern.indices), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(preset.pattern[index].isRest
                                  ? Color.restGray
                                  : Color(hex: plan.shiftDef(preset.pattern[index]).colorHex))
                            .frame(height: 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color.brand.opacity(0.10) : Color.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.brand : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 班次时间设置

struct ShiftSettingsView: View {
    @EnvironmentObject private var store: PlanStore

    private let editable: [ShiftKind] = [.morning, .afternoon, .night, .study]

    var body: some View {
        Form {
            ForEach(editable) { kind in
                Section {
                    DatePicker("开始时间", selection: startBinding(kind), displayedComponents: .hourAndMinute)
                    Stepper(value: hoursBinding(kind), in: 4...12) {
                        Text("时长 \(store.plan.shiftDef(kind).hours) 小时")
                    }
                    Stepper(value: leadBinding(kind), in: 0...120, step: 5) {
                        Text("提前 \(store.plan.shiftDef(kind).leadMinutes) 分钟")
                    }
                    Toggle("为该班次响铃", isOn: alarmBinding(kind))
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: store.plan.shiftDef(kind).colorHex))
                            .frame(width: 8, height: 8)
                        Text(store.plan.shiftDef(kind).name)
                    }
                } footer: {
                    Text("闹钟时间 = 开始时间 − 提前量；夜班 00:00 会落到前一天晚上。")
                }
            }
        }
        .navigationTitle("班次时间")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startBinding(_ kind: ShiftKind) -> Binding<Date> {
        Binding(
            get: {
                let def = store.plan.shiftDef(kind)
                return CalendarX.cal.date(
                    byAdding: .minute,
                    value: def.startMinute,
                    to: CalendarX.startOfDay(Date())
                ) ?? Date()
            },
            set: { newValue in
                var def = store.plan.shiftDef(kind)
                def.startMinute = CalendarX.minuteOfDay(newValue)
                store.updateShift(def)
            }
        )
    }

    private func hoursBinding(_ kind: ShiftKind) -> Binding<Int> {
        Binding(
            get: { store.plan.shiftDef(kind).hours },
            set: { value in
                var def = store.plan.shiftDef(kind)
                def.hours = value
                store.updateShift(def)
            }
        )
    }

    private func leadBinding(_ kind: ShiftKind) -> Binding<Int> {
        Binding(
            get: { store.plan.shiftDef(kind).leadMinutes },
            set: { value in
                var def = store.plan.shiftDef(kind)
                def.leadMinutes = value
                store.updateShift(def)
            }
        )
    }

    private func alarmBinding(_ kind: ShiftKind) -> Binding<Bool> {
        Binding(
            get: { store.plan.shiftDef(kind).alarmEnabled },
            set: { value in
                var def = store.plan.shiftDef(kind)
                def.alarmEnabled = value
                store.updateShift(def)
            }
        )
    }
}
