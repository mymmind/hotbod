import SwiftUI

enum WorkoutHeroRefreshKind {
    case regenerate
    case switchSplit
    case trainAnyway
    case readiness
}

struct ForgeHeroRegeneratingOverlay: View {
    let isSpinning: Bool

    var body: some View {
        ZStack {
            ForgeColors.surfaceInverse.opacity(0.82)

            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: ForgeIcons.lg + 4, weight: .semibold))
                    .foregroundStyle(ForgeColors.accent)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                        value: isSpinning
                    )

                Text("Building new session...")
                    .font(ForgeTypography.caption)
                    .tracking(3)
                    .foregroundStyle(ForgeColors.surface.opacity(0.92))
            }
        }
    }
}

@MainActor
enum WorkoutHeroRefreshRunner {
    static func performAnimatedRefresh(
        kind: WorkoutHeroRefreshKind,
        environment: AppEnvironment,
        feedback: ForgeFeedbackService,
        isRegenerating: @MainActor @Sendable () -> Bool,
        beginRegenerating: @MainActor @escaping @Sendable () -> Void,
        endRegenerating: @MainActor @escaping @Sendable () -> Void,
        refresh: @MainActor @escaping @Sendable (WorkoutHeroRefreshKind) async -> Bool,
        reload: @MainActor @escaping @Sendable () async -> Void,
        onGenerationFailure: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard !isRegenerating() else { return }
        if environment.isWorkoutGenerationInFlight {
            environment.cancelWorkoutGenerationIfNeeded()
        }
        beginRegenerating()
        Task { @MainActor in
            defer { endRegenerating() }

            async let refreshResult = refresh(kind)
            try? await Task.sleep(for: ForgeMotion.regenerateMinimum)

            let succeeded = await refreshResult
            if succeeded {
                feedback.play(feedbackKind(for: kind))
            } else if environment.paywallFeature == nil {
                if environment.lastGenerationFailure != nil {
                    onGenerationFailure?()
                } else {
                    feedback.play(.warning)
                }
            }
            await reload()

            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private static func feedbackKind(for kind: WorkoutHeroRefreshKind) -> ForgeFeedbackEvent {
        switch kind {
        case .regenerate: .workoutRegenerate
        case .switchSplit, .trainAnyway, .readiness: .success
        }
    }
}
