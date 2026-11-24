import SwiftUI

struct DayPick: Identifiable {
    let id: String
    let date: Date
}

struct MonthCell: Identifiable {
    let id: String
    let date: Date
    let inMonth: Bool
}

// MARK: - 月历

struct CalendarTab: View {
    @EnvironmentObject private var store: PlanStore
    @State private var month = CalendarX.startOfMonth(Date())
    @State private var picked: DayPick?
    @State private var showSettings = false

    private var plan: Plan { store.plan }
    private var today: Date { CalendarX.startOfDay(Date()) }

    private var nextAlarm: PlannedAlarm? {
        plan.upcomingAlarms(from: Date(), days: 1).first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroCardView(alarm: nextAlarm, plan: plan)
                    monthCard
                    summaryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Color.pageBackground)
            .navigationTitle("班表")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("今天") { month = CalendarX.startOfMonth(today) }
                        .font(.subheadline.weight(.semibold))
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(item: $picked) { pick in
                DayDetailView(date: pick.date)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }

    // MARK: 月历卡片

    private var monthCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CalendarX.monthTitle(month))
                    .font(.system(size: 17, weight: .semibold))
                Text(plan.patternName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { month = CalendarX.addMonths(month, -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                Button { month = CalendarX.addMonths(month, 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(CalendarX.weekShort, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(cells) { cell in
                    Button {
                        picked = DayPick(id: cell.id, date: cell.date)
                    } label: {
                        DayCellView(
                            date: cell.date,
                            def: plan.shiftDef(plan.shift(on: cell.date)),
                            inMonth: cell.inMonth,
                            isToday: CalendarX.startOfDay(cell.date) == today,
                            overridden: plan.isOverridden(cell.date)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card(padding: 12)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    private var cells: [MonthCell] {
        let lead = CalendarX.weekdayIndex(month)
        let total = CalendarX.daysInMonth(month)
        let count = ((lead + total + 6) / 7) * 7
        return (0..<count).map { index in
            let date = CalendarX.addDays(month, index - lead)
            let inMonth = CalendarX.cal.isDate(date, equalTo: month, toGranularity: .month)
            return MonthCell(id: CalendarX.isoKey(date), date: date, inMonth: inMonth)
        }
    }

    // MARK: 月度统计

    private var counts: [ShiftKind: Int] {
        var result: [ShiftKind: Int] = [:]
        for cell in cells where cell.inMonth {
            let kind = plan.shift(on: cell.date)
            result[kind, default: 0] += 1
        }
        return result
    }

    private var workDays: Int {
        counts.filter { !$0.key.isRest }.reduce(0) { $0 + $1.value }
    }

    private var workHours: Int {
        counts.reduce(0) { partial, item in
            partial + plan.shiftDef(item.key).hours * item.value
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(ShiftKind.allCases) { kind in
                    StatItem(def: plan.shiftDef(kind), count: counts[kind] ?? 0)
                }
            }
            HStack {
                Text("出勤 \(workDays) 天 · 休息 \(counts[.rest] ?? 0) 天")
                Spacer()
                Text("约 \(workHours) 小时")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
        }
        .card()
    }
}

// MARK: - 单个日期格子

struct DayCellView: View {
    let date: Date
    let def: ShiftDef
    let inMonth: Bool
    let isToday: Bool

    var overridden: Bool = false

    private var dayNumber: Int {
        CalendarX.cal.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(dayNumber)")
                .font(.system(size: 15, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.5)))
                .frame(width: 28, height: 28)
                .background {
                    if isToday { Circle().fill(Color.brand) }
                }

            ShiftTag(def: def, overridden: overridden)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .opacity(inMonth ? 1 : 0.55)
        .contentShape(Rectangle())
    }
}
