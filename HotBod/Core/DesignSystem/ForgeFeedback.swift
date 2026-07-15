import SwiftUI

extension View {
    func forgeSetCompleteFlash(isActive: Bool) -> some View {
        modifier(ForgeSetCompleteFlashModifier(isActive: isActive))
    }

    func forgePRFlash(isActive: Bool) -> some View {
        modifier(ForgePRFlashModifier(isActive: isActive))
    }
}

private struct ForgeSetCompleteFlashModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(ForgeColors.accentGreen.opacity(isActive && !reduceMotion ? 0.14 : 0))
                    .animation(ForgeMotion.fast, value: isActive)
            )
            .scaleEffect(isActive && !reduceMotion ? 1.01 : 1)
            .animation(ForgeMotion.fast, value: isActive)
    }
}

private struct ForgePRFlashModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(ForgeColors.accentAmber.opacity(0.85), lineWidth: 2)
                        .transition(.opacity)
                }
            }
            .animation(ForgeMotion.standard, value: isActive)
    }
}

struct ForgeRestTimerBar: View {
    let secondsRemaining: Int
    let totalSeconds: Int
    let onAddTime: () -> Void
    let onSkip: () -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    var body: some View {
        HStack(spacing: ForgeSpacing.s4) {
            ZStack {
                Circle()
                    .stroke(ForgeColors.surface.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        secondsRemaining <= 10 ? ForgeColors.accentAmber : ForgeColors.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(ForgeMotion.fast, value: progress)
                Text("\(secondsRemaining)")
                    .font(ForgeTypography.monoMetric)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("REST")
                    .font(ForgeTypography.tabLabel)
                    .tracking(ForgeTracking.tight)
                Text(WorkoutSessionCalculator.formattedElapsed(seconds: secondsRemaining))
                    .font(ForgeTypography.metric)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button("+30s", action: onAddTime)
                .font(ForgeTypography.label)
            Button("Skip", action: onSkip)
                .font(ForgeTypography.label.weight(.semibold))
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
        .background(ForgeColors.surfaceInverse)
        .foregroundStyle(ForgeColors.textOnInverse)
    }
}
