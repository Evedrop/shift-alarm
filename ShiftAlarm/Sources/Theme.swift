import SwiftUI
import UIKit

// MARK: - 颜色

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static let brand = Color(hex: "#FF8A00")
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let restGray = Color(uiColor: .tertiarySystemFill)
}

// MARK: - 卡片

struct CardBackground: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - 小标题

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 班次小色块

struct ShiftTag: View {
    let def: ShiftDef
    var overridden: Bool = false

    var body: some View {
        Text(def.short)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(def.isRest ? Color.secondary : .white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(def.isRest ? Color.restGray : Color(hex: def.colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                if overridden {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.7),
                                      style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
    }
}

// MARK: - 统计列

struct StatItem: View {
    let def: ShiftDef
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(def.isRest ? Color.secondary : Color(hex: def.colorHex))
            HStack(spacing: 3) {
                Circle()
                    .fill(def.isRest ? Color.restGray : Color(hex: def.colorHex))
                    .frame(width: 5, height: 5)
                Text(def.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 主按钮

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.brand)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - 下一个闹钟卡片

struct HeroCardView: View {
    let alarm: PlannedAlarm?
    let plan: Plan
    var authText: String = "系统闹钟 · 待授权"
    var authTint: Color = .white.opacity(0.6)
    var onTapBell: (() -> Void)? = nil

    private var def: ShiftDef? {
        alarm.map { plan.shiftDef($0.kind) }
    }

    /// Text(timerInterval:) 要求上下界有序，且不能是过去
    private func countdownRange(for alarm: PlannedAlarm) -> ClosedRange<Date> {
        let now = Date()
        let upper = max(now.addingTimeInterval(1), alarm.fireDate)
        return now...upper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 6, height: 6)
                Text("下一个闹钟")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Text(authText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(authTint)
            }

            if let alarm, let def {
                Text(CalendarX.timeLabel(alarm.minutes))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                Text("\(CalendarX.relativeDay(alarm.fireDate)) \(CalendarX.week(alarm.fireDate)) · \(def.name) \(CalendarX.timeLabel(def.startMinute)) 开始")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 2)
            } else {
                Text("闹钟已关闭")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)
                Text("打开总开关后会按排班自动响铃")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
                .padding(.vertical, 10)

            HStack(spacing: 4) {
                if let alarm {
                    Text("还有")
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(timerInterval: countdownRange(for: alarm), countsDown: true)
                        .foregroundStyle(Color(hex: "#FFB340"))
                        .monospacedDigit()
                } else {
                    Text("未来 14 天按规律排班")
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                if let onTapBell {
                    Button(action: onTapBell) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.brand))
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 12.5, weight: .medium))
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: "#1B1F2E"), Color(hex: "#0C0E15")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.brand.opacity(0.42), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: 260)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
