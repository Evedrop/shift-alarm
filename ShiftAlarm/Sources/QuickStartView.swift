import SwiftUI

/// 快速排班：选班组 → 点一天 → 选那天的班（同一天有两个同班次时选第几个）→ 逐天微调 → 开始。
struct QuickStartView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss

    @State private var month = CalendarX.startOfMonth(Date())
    @State private var picked = CalendarX.startOfDay(Date())
    @State private var kind: ShiftKind = .morning
    @State private var patternIndex: Int? = nil          // 选中的是循环里第几个
    @State private var dayEdits: [String: ShiftKind] = [:] // 逐天修改（未提交）

    private var plan: Plan { store.plan }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    crewRow
                    stepTitle("① 从哪天开始")
                    miniCalendar
                    stepTitle("② \(CalendarX.md(picked)) \(CalendarX.week(picked)) 上什么班")
                    shiftPicker
                    occurrencePicker
                    stepTitle("③ 后面这样排（可逐天改）")
                    editRows
                    hint
                    Button("就从这天开始") { apply() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 2)
                }
                .padding(16)
            }
            .background(Color.pageBackground)
            .navigationTitle("快速排班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.brand.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text("当前规律").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(plan.patternName).font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            Menu {
                ForEach(Presets.all) { preset in
                    Button(preset.name) {
                        store.apply(preset: preset)
                        store.normalizeCrews()
                        patternIndex = nil
                        dayEdits = [:]
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("换一个")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.restGray))
                .foregroundStyle(Color.primary)
            }
        }
        .card()
    }

    @ViewBuilder
    private var crewRow: some View {
        if plan.crews > 1 {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("我是哪个班")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("切换后整月按这个班算")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 6) {
                    ForEach(0..<plan.crews, id: \.self) { crew in
                        Button {
                            store.plan.myCrew = crew
                                    } label: {
                            Text(plan.crewName(crew))
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(crew == plan.myCrew ? Color.brand : Color.restGray))
                                .foregroundStyle(crew == plan.myCrew ? Color.white : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .card(padding: 12)
        }
    }

    private func stepTitle(_ text: String) -> some View {
        HStack {
            Text(text).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: 月历

    private var days: [Date] {
        let lead = CalendarX.weekdayIndex(month)
        let total = CalendarX.daysInMonth(month)
        let count = ((lead + total + 6) / 7) * 7
        return (0..<count).map { CalendarX.addDays(month, $0 - lead) }
    }

    private var miniCalendar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { month = CalendarX.addMonths(month, -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 30, height: 30)
                }
                Spacer()
                Text(CalendarX.monthTitle(month)).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { month = CalendarX.addMonths(month, 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 30, height: 30)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                ForEach(CalendarX.weekShort, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(days, id: \.self) { day in
                    dayButton(day)
                }
            }
        }
        .card(padding: 12)
    }

    private func dayButton(_ day: Date) -> some View {
        let isPicked = CalendarX.isoKey(day) == CalendarX.isoKey(picked)
        let inMonth = CalendarX.cal.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = CalendarX.startOfDay(day) == CalendarX.startOfDay(Date())
        return Button {
            picked = CalendarX.startOfDay(day)
            dayEdits = [:]
            patternIndex = nil
        } label: {
            Text("\(CalendarX.cal.component(.day, from: day))")
                .font(.system(size: 15, weight: isPicked ? .bold : .regular))
                .foregroundStyle(isPicked ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.45)))
                .frame(width: 32, height: 32)
                .background {
                    if isPicked {
                        Circle().fill(Color.brand)
                    } else if isToday {
                        Circle().strokeBorder(Color.brand.opacity(0.5), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: 班次 + 第几个

    private var shiftPicker: some View {
        Picker("班次", selection: Binding(
            get: { kind },
            set: { newValue in
                kind = newValue
                patternIndex = nil
            }
        )) {
            ForEach(ShiftKind.allCases) { item in
                Text(plan.shiftDef(item).name).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 这个班次在循环里出现的位置（早/中/夜各两个，休息四个）
    private var occurrenceIndices: [Int] {
        plan.pattern.indices.filter { plan.pattern[$0] == kind }
    }

    private var selectedIndex: Int? {
        if let patternIndex, occurrenceIndices.contains(patternIndex) { return patternIndex }
        return occurrenceIndices.first
    }

    private func ordinal(_ index: Int) -> Int {
        (occurrenceIndices.firstIndex(of: index) ?? 0) + 1
    }

    @ViewBuilder
    private var occurrencePicker: some View {
        if occurrenceIndices.count > 1 {
            HStack(spacing: 8) {
                ForEach(occurrenceIndices, id: \.self) { index in
                    Button {
                        patternIndex = index
                    } label: {
                        VStack(spacing: 1) {
                            Text("第 \(ordinal(index)) 个\(plan.shiftDef(kind).short)")
                                .font(.system(size: 12, weight: .semibold))
                            Text("循环第 \(index + 1) 天")
                                .font(.system(size: 9))
                                .opacity(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(index == selectedIndex ? Color.brand : Color.restGray))
                        .foregroundStyle(index == selectedIndex ? Color.white : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 逐天编辑

    private var anchor: Date? {
        guard let index = selectedIndex else { return nil }
        return plan.anchorAligned(to: picked, patternIndex: index)
    }

    private var editDays: [Date] {
        (0..<7).map { CalendarX.addDays(picked, $0) }
    }

    private func baseKind(on day: Date) -> ShiftKind {
        if let anchor { return plan.shiftPreview(on: day, anchor: anchor) }
        return plan.shift(on: day)
    }

    private func shownKind(on day: Date) -> ShiftKind {
        dayEdits[CalendarX.isoKey(day)] ?? baseKind(on: day)
    }

    private func setKind(_ newKind: ShiftKind, on day: Date) {
        let key = CalendarX.isoKey(day)
        if newKind == baseKind(on: day) {
            dayEdits.removeValue(forKey: key)
        } else {
            dayEdits[key] = newKind
        }
    }

    private var editRows: some View {
        VStack(spacing: 0) {
            ForEach(editDays, id: \.self) { day in
                HStack(spacing: 8) {
                    Text("\(CalendarX.md(day).replacingOccurrences(of: "月", with: "/").replacingOccurrences(of: "日", with: "")) \(CalendarX.weekShort[CalendarX.weekdayIndex(day)])")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(dayEdits[CalendarX.isoKey(day)] != nil ? Color.brand : Color.secondary)
                        .frame(width: 72, alignment: .leading)

                    ForEach(ShiftKind.allCases) { item in
                        Button {
                            setKind(item, on: day)
                        } label: {
                            Text(plan.shiftDef(item).short)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(chipBackground(item, on: day)))
                                .foregroundStyle(chipForeground(item, on: day))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)

                if day != editDays.last {
                    Divider()
                }
            }
        }
        .card(padding: 10)
    }

    private func chipBackground(_ item: ShiftKind, on day: Date) -> Color {
        guard item == shownKind(on: day) else { return Color.restGray }
        let def = plan.shiftDef(item)
        return def.isRest ? Color.restGray : Color(hex: def.colorHex)
    }

    private func chipForeground(_ item: ShiftKind, on day: Date) -> Color {
        guard item == shownKind(on: day) else { return Color.secondary }
        return plan.shiftDef(item).isRest ? Color.secondary : Color.white
    }

    @ViewBuilder
    private var hint: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let anchor {
                Text("已对齐：循环起点 \(CalendarX.md(anchor)) \(CalendarX.week(anchor))")
            } else {
                Text("「\(plan.patternName)」里没有「\(plan.shiftDef(kind).name)」，这天会作为单日调整")
            }
            if !dayEdits.isEmpty {
                Button("清除逐天修改") { dayEdits = [:] }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brand)
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: 应用

    private func apply() {
        let key = CalendarX.isoKey(picked)
        if let index = selectedIndex, let aligned = plan.anchorAligned(to: picked, patternIndex: index) {
            store.plan.anchor = aligned
            store.plan.overrides.removeValue(forKey: key)
        } else {
            store.plan.overrides[key] = kind
        }
        for (dayKey, value) in dayEdits {
            store.plan.overrides[dayKey] = value
        }
        dismiss()
    }
}
