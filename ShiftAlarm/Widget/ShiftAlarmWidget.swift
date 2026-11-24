import WidgetKit
import SwiftUI
import ActivityKit

@main
struct ShiftAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShiftLiveActivity()
    }
}

/// 锁屏卡片 + 灵动岛。闹钟停掉之后它还在，提醒你今天什么班。
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.black.opacity(0.65))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(hex: context.state.colorHex))
                            .frame(width: 8, height: 26)
                        Text(context.state.shortName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .time)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(context.state.statusText)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Text(context.state.shortName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: context.state.colorHex))
            } compactTrailing: {
                Text(context.state.endDate, style: .time)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Text(context.state.shortName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: context.state.colorHex))
            }
            .keylineTint(Color(hex: context.state.colorHex))
        }
    }

    private func lockScreen(_ context: ActivityViewContext<ShiftActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: context.state.colorHex))
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text("今天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(context.state.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(context.state.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("下班")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(context.state.endDate, style: .time)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
