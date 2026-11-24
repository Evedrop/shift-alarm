import SwiftUI

struct CrewsTab: View {
    @EnvironmentObject private var store: PlanStore
    @State private var weekStart = CalendarX.startOfWeek(Date())
    @State private var showRename = false

    private var plan: Plan { store.plan }
    private var days: [Date] { (0..<7).map { CalendarX.addDays(weekStart, $0) } }
    private var today: Date { CalendarX.startOfDay(Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if plan.crews > 1 {
                        weekCard
                        matrixCard
                        myWeekCard
                        Text("五班三倒：10 天一轮，每班 2 早 · 2 中 · 2 夜 · 1 学 · 3 休；5 个班组错开 2 天，每天恰好 3 个班顶岗。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Color.pageBackground)
            .navigationTitle("班组")
            .toolbar {
                if plan.crews > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("改名") { showRename = true }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .sheet(isPresented: $showRename) {
            CrewRenameView()
                .environmentObject(store)
        }
    }

    // MARK: 周切换

    private var weekCard: some View {
        HStack {
            Text("\(CalendarX.md(weekStart)) – \(CalendarX.md(CalendarX.addDays(weekStart, 6)))")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button { weekStart = CalendarX.addDays(weekStart, -7) } label: {
                Image(systemName: "chevron.left").frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Button("本周") { weekStart = CalendarX.startOfWeek(Date()) }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Color.restGray))
                .buttonStyle(.plain)
            Button { weekStart = CalendarX.addDays(weekStart, 7) } label: {
                Image(systemName: "chevron.right").frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .card(padding: 12)
    }

    // MARK: 班组矩阵

    private var matrixCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Color.clear.frame(width: 42, height: 30)
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 1) {
                        Text(CalendarX.weekShort[CalendarX.weekdayIndex(day)])
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("\(CalendarX.cal.component(.day, from: day))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(CalendarX.startOfDay(day) == today ? Color.brand : Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<plan.crews, id: \.self) { crew in
                HStack(spacing: 3) {
                    Button {
                        store.plan.myCrew = crew
                    } label: {
                        Text(plan.crewName(crew))
                            .font(.system(size: 10.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(crew == plan.myCrew ? Color.brand : Color.secondary)
                            .frame(width: 42, height: 34)
                            .background {
                                if crew == plan.myCrew {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.brand.opacity(0.12))
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    ForEach(days, id: \.self) { day in
                        CrewCell(def: plan.shiftDef(plan.shift(on: day, crew: crew)))
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(ShiftKind.allCases) { kind in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(kind.isRest ? Color.restGray : Color(hex: plan.shiftDef(kind).colorHex))
                            .frame(width: 6, height: 6)
                        Text(plan.shiftDef(kind).name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("点班组名切换视角")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 6)
        }
        .card(padding: 11)
    }

    // MARK: 我的这一周

    private var myCounts: [ShiftKind: Int] {
        var result: [ShiftKind: Int] = [:]
        for day in days {
            result[plan.shift(on: day), default: 0] += 1
        }
        return result
    }

    private var myWeekCard: some View {
        let counts = myCounts
        let work = counts.filter { !$0.key.isRest }.reduce(0) { $0 + $1.value }
        let rest = counts[.rest] ?? 0
        return VStack(spacing: 12) {
            HStack {
                Text("本周我的班").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(plan.crewName(plan.myCrew)).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(ShiftKind.allCases) { kind in
                    StatItem(def: plan.shiftDef(kind), count: counts[kind] ?? 0)
                }
            }
            HStack {
                Text("上班 \(work) 天 · 休息 \(rest) 天")
                Spacer()
                Text("每天 3 个班顶岗")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: 单人排班时的空态

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.brand)
            Text("没有多班组轮转")
                .font(.headline)
            Text("「\(plan.patternName)」是单人排班。换成五班三倒或四班三倒，就能看到全班组的排版。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("切换到五班三倒") {
                guard let preset = Presets.all.first else { return }
                store.apply(preset: preset)
                store.normalizeCrews()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(.vertical, 14)
        .card()
    }
}

struct CrewCell: View {
    let def: ShiftDef

    var body: some View {
        Text(def.short)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(def.isRest ? Color.secondary : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(def.isRest ? Color.restGray : Color(hex: def.colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - 改名

struct CrewRenameView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [String] = []

    private let defaults = ["甲班", "乙班", "丙班", "丁班", "戊班", "己班", "庚班", "辛班"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<max(store.plan.crews, 1), id: \.self) { index in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14)
                            TextField(defaults[min(index, defaults.count - 1)],
                                      text: binding(index))
                                .textInputAutocapitalization(.never)
                                .submitLabel(.done)
                        }
                    }
                } footer: {
                    Text("最多 6 个字。改完点「完成」，月历、日详情、班组页会一起更新。")
                }

                Section {
                    Button("恢复默认名称") {
                        drafts = defaults
                    }
                }
            }
            .navigationTitle("班组名称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            var initial = store.plan.crewNames
            while initial.count < store.plan.crews {
                initial.append(defaults[min(initial.count, defaults.count - 1)])
            }
            drafts = initial
        }
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index < drafts.count ? drafts[index] : "" },
            set: { newValue in
                var value = newValue.replacingOccurrences(of: "\n", with: "")
                if value.count > 6 { value = String(value.prefix(6)) }
                if index < drafts.count {
                    drafts[index] = value
                } else {
                    while drafts.count <= index { drafts.append("") }
                    drafts[index] = value
                }
            }
        )
    }

    private func save() {
        for index in 0..<store.plan.crews {
            let raw = index < drafts.count ? drafts[index] : ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            store.renameCrew(index, to: trimmed.isEmpty ? defaults[min(index, defaults.count - 1)] : trimmed)
        }
        dismiss()
    }
}
