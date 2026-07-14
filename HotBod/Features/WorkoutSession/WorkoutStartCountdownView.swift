import SwiftUI

struct WorkoutStartCountdownView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.forgeFeedback) private var feedback

    @State private var phase: Phase = .count(3)
    @State private var tick = 0
    @State private var numberScale: CGFloat = 1.55
    @State private var numberOpacity: Double = 0
    @State private var messageScale: CGFloat = 0.88
    @State private var messageOpacity: Double = 0
    @State private var ringProgress: CGFloat = 0
    @State private var ringOpacity: Double = 0.85
    @State private var flashOpacity: Double = 0
    @State private var sweepOffset: CGFloat = -1

    private let rallyMessage = WorkoutStartCountdown.randomMessage()

    private enum Phase: Equatable {
        case count(Int)
        case rally(String)

        var isRally: Bool {
            if case .rally = self { return true }
            return false
        }
    }

    var body: some View {
        ZStack {
            ForgeColors.surfaceInverse
                .ignoresSafeArea()

            pulseRings

            VStack(spacing: ForgeSpacing.s6) {
                Text("GET READY")
                    .font(ForgeTypography.label)
                    .tracking(ForgeTracking.eyebrowWide)
                    .foregroundStyle(ForgeColors.accent)
                    .opacity(phase.isRally ? 0 : 1)

                centerContent
                    .frame(minHeight: 200)

                accentSweep
            }
            .padding(.horizontal, ForgeSpacing.s5)

            ForgeColors.textOnInverse
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countdown.start")
        .task {
            if reduceMotion {
                await runReducedMotionSequence()
            } else {
                await runFullSequence()
            }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch phase {
        case .count(let value):
            Text("\(value)")
                .font(.system(size: 168, weight: .black, design: .monospaced))
                .foregroundStyle(ForgeColors.textOnInverse)
                .scaleEffect(numberScale)
                .opacity(numberOpacity)
                .forgeMetricPulse(value: tick)
                .accessibilityLabel("\(value)")
        case .rally(let message):
            Text(message)
                .font(ForgeTypography.display)
                .multilineTextAlignment(.center)
                .foregroundStyle(ForgeColors.textOnInverse)
                .scaleEffect(messageScale)
                .opacity(messageOpacity)
                .padding(.horizontal, ForgeSpacing.s3)
                .accessibilityLabel(message)
        }
    }

    private var pulseRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        ForgeColors.accent.opacity(0.55 - Double(index) * 0.14),
                        lineWidth: ForgeBorder.hairline * 2
                    )
                    .scaleEffect(0.35 + ringProgress + CGFloat(index) * 0.12)
                    .opacity(ringOpacity * (1 - Double(index) * 0.22))
            }
        }
        .allowsHitTesting(false)
    }

    private var accentSweep: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(ForgeColors.accentGradient)
                .frame(width: proxy.size.width * 0.42, height: 4)
                .offset(x: sweepOffset * proxy.size.width)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 4)
        .opacity(phase.isRally ? 1 : 0.65)
    }

    @MainActor
    private func runReducedMotionSequence() async {
        phase = .rally(rallyMessage)
        messageOpacity = 1
        messageScale = 1
        feedback.play(.success)

        try? await Task.sleep(for: WorkoutStartCountdown.reducedMotionHoldDuration)
        guard !Task.isCancelled else { return }
        onComplete()
    }

    @MainActor
    private func runFullSequence() async {
        for count in [3, 2, 1] {
            await animateCount(count)
            guard !Task.isCancelled else { return }
        }

        await animateRally()
        guard !Task.isCancelled else { return }

        try? await Task.sleep(for: WorkoutStartCountdown.messageHoldDuration)
        guard !Task.isCancelled else { return }
        onComplete()
    }

    @MainActor
    private func animateCount(_ value: Int) async {
        phase = .count(value)
        tick += 1
        numberScale = 1.55
        numberOpacity = 0
        ringProgress = 0
        ringOpacity = 0.9
        flashOpacity = 0
        sweepOffset = -1

        feedback.play(value == 1 ? .increase : .buttonPress)

        withAnimation(.spring(duration: 0.55, bounce: 0.28)) {
            numberScale = 1
            numberOpacity = 1
            ringProgress = 1.05
        }

        withAnimation(.easeOut(duration: 0.18)) {
            flashOpacity = value == 1 ? 0.22 : 0.12
        }

        withAnimation(.easeInOut(duration: 0.85)) {
            sweepOffset = 1.2
        }

        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            flashOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(480))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            numberOpacity = 0
            ringOpacity = 0.2
        }

        try? await Task.sleep(for: WorkoutStartCountdown.tickDuration)
    }

    @MainActor
    private func animateRally() async {
        phase = .rally(rallyMessage)
        messageScale = 0.88
        messageOpacity = 0
        ringProgress = 0.2
        ringOpacity = 0.75
        sweepOffset = -1

        feedback.play(.success)

        withAnimation(.spring(duration: 0.62, bounce: 0.34)) {
            messageScale = 1
            messageOpacity = 1
            ringProgress = 1.25
            ringOpacity = 0.95
        }

        withAnimation(.easeInOut(duration: 0.9)) {
            sweepOffset = 1.2
        }

        withAnimation(.easeOut(duration: 0.16)) {
            flashOpacity = 0.18
        }

        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.24)) {
            flashOpacity = 0
        }
    }
}

#Preview("Countdown") {
    WorkoutStartCountdownView(onComplete: {})
}
