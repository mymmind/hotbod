import SwiftUI

struct ForgeHoldTimerBar: View {
    let secondsRemaining: Int
    let totalSeconds: Int
    let exerciseName: String?
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    var body: some View {
        HStack(spacing: ForgeSpacing.s4) {
            ZStack {
                Circle()
                    .stroke(ForgeColors.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: isRunning ? progress : 1)
                    .stroke(
                        secondsRemaining <= 10 && isRunning
                            ? ForgeColors.accentAmber
                            : ForgeColors.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(ForgeMotion.fast, value: progress)
                Text(isRunning ? "\(secondsRemaining)" : "\(totalSeconds)")
                    .font(ForgeTypography.monoMetric)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("HOLD")
                    .font(ForgeTypography.tabLabel)
                    .tracking(ForgeTracking.tight)
                if let exerciseName, !exerciseName.isEmpty {
                    Text(exerciseName)
                        .font(ForgeTypography.tabLabel)
                        .foregroundStyle(ForgeColors.textSecondary)
                        .lineLimit(1)
                }
                Text(
                    WorkoutSessionCalculator.formattedElapsed(
                        seconds: isRunning ? secondsRemaining : totalSeconds
                    )
                )
                .font(ForgeTypography.metric)
                .contentTransition(.numericText())
            }

            Spacer()

            if isRunning {
                Button(action: onStop) {
                    Text("Stop")
                        .font(ForgeTypography.label.weight(.semibold))
                        .frame(minWidth: 64, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hold.stop")
            } else {
                Button(action: onStart) {
                    Text("Start")
                        .font(ForgeTypography.label.weight(.semibold))
                        .frame(minWidth: 64, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hold.start")
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
        .background(ForgeColors.surface)
        .foregroundStyle(ForgeColors.textPrimary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ForgeColors.border)
                .frame(height: ForgeBorder.hairline)
        }
    }
}
