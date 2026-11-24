import SwiftUI

/// 快速排班：点一天 → 选那天的班 → 后面自动按规律往下排。
/// 不用再去规律页改「起始日」和逐天微调。
struct QuickStartView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss

    @State private var month = CalendarX.startOfMonth(Date())
    @State private var picked = CalendarX.startOfDay(Date())
    @State private var kind: ShiftKind = .morning

    private var plan: Plan { store.plan }

    /// 选中「这天 + 这个班」后应该用的循环起点
    private var anchor: Date? {
        plan.alignedAnchor(for: picked, kind: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    stepTitle("① 从哪天开始")
                    miniCalendar

                    stepTitle("② \(CalendarX.md(picked)) \(CalendarX.week(picked)) 上什么班")
                    shiftPicker
                    kindHint

                    stepTitle("③ 后面自动这样排")
                    previewCard

                    Button("就从这天开始") { apply() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
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

    // MARK: 顶部：当前规律

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.brand.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text("当前规律")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(plan.patternName)
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            Menu {
                ForEach(Presets.all) { preset in
                    Button(preset.name) {
                        store.apply(preset: preset)
                        store.normalizeCrews()
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

    private func stepTitle(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
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
                Text(CalendarX.monthTitle(month))
                    .font(.system(size: 15, weight: .semibold))
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                      spacing: 2) {
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
        } label: {
            Text("\(CalendarX.cal.component(.day, from: day))")
                .font(.system(size: 15, weight: isPicked ? .bold : .regular))
                .foregroundStyle(isPicked ? Color.white
                                 : (inMonth ? Color.primary : Color.secondary.opacity(0.45)))
                .frame(width: 34, height: 34)
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

    // MARK: 班次

    private var shiftPicker: some View {
        Picker("班次", selection: $kind) {
            ForEach(ShiftKind.allCases) { item in
                Text(plan.shiftDef(item).name).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var kindHint: some View {
        if anchor == nil {
            Text("「\(plan.patternName)」这一轮里没有「\(plan.shiftDef(kind).name)」，这天会作为单日调整，后面的日子仍按原规律。想整段都换，点右上「换一个」选含这个班的规律（五班三倒 / 四班三倒）。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .multilineTextAlignment(.leading)
        } else if let anchor {
            Text("已自动对齐：循环起点 \(CalendarX.md(anchor)) \(CalendarX.week(anchor))")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: 预览

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let anchor {
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { offset in
                        previewColumn(offset: offset, anchor: anchor)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<8, id: \.self) { offset in
                        let day = CalendarX.addDays(picked, offset)
                        let isPickedDay = offset == 0
                        VStack(spacing: 4) {
                            Text(isPickedDay ? "这天" : CalendarX.weekShort[CalendarX.weekdayIndex(day)])
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            ShiftTag(def: plan.shiftDef(isPickedDay ? kind : plan.shift(on: day)))
                                .opacity(isPickedDay ? 1 : 0.45)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Text("之后按「\(plan.patternName)」一直循环下去，不用再逐天设置。个别的换班、请假，点月历里那天单独改。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func previewColumn(offset: Int, anchor: Date) -> some View {
        let day = CalendarX.addDays(picked, offset)
        let simulated = plan.shiftPreview(on: day, anchor: anchor)
        return VStack(spacing: 4) {
            Text(offset == 0 ? "这天" : CalendarX.weekShort[CalendarX.weekdayIndex(day)])
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            ShiftTag(def: plan.shiftDef(simulated))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 应用

    private func apply() {
        store.refreshFromQuickStart(on: picked, kind: kind)
        dismiss()
    }
}
