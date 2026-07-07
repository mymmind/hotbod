import SwiftUI
import Pow

enum ForgeMotion {
    static let instant = Animation.linear(duration: 0)
    static let fast = Animation.smooth(duration: 0.15)
    static let standard = Animation.smooth(duration: 0.25)
    static let quick = fast
    static let exercise = Animation.smooth(duration: 0.40)
    static let regenerate = Animation.smooth(duration: 0.40)
    static let regenerateMinimum: Duration = .milliseconds(720)

    static var appear: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -12)),
            removal: .opacity
        )
    }

    static var rise: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 20)),
            removal: .opacity
        )
    }

    static var slideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    static var exerciseChange: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 20)),
            removal: .opacity.combined(with: .offset(y: -12))
        )
    }

    static var disclosureExpand: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -8)),
            removal: .opacity.combined(with: .offset(y: -4))
        )
    }

    static func staggerDelay(for index: Int) -> Double {
        Double(index) * 0.07
    }

    static func animation(_ base: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? instant : base
    }

    static func transition(_ base: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : base
    }
}

extension View {
    @ViewBuilder
    func forgeStaggeredAppear(index: Int, isVisible: Bool) -> some View {
        modifier(ForgeStaggeredAppearModifier(index: index, isVisible: isVisible))
    }

    func forgeAnimatedContent<ID: Hashable>(id: ID) -> some View {
        modifier(ForgeAnimatedContentModifier(id: id))
    }

    func forgeExerciseContent<ID: Hashable>(id: ID) -> some View {
        modifier(ForgeExerciseContentModifier(id: id))
    }

    func forgeMetricPulse<V: Equatable>(value: V) -> some View {
        modifier(ForgeMetricPulseModifier(value: value))
    }

    func forgeValidationShake<V: Equatable>(value: V) -> some View {
        modifier(ForgeValidationShakeModifier(value: value))
    }

    func forgeSuccessHaptic<V: Equatable>(value: V) -> some View {
        modifier(ForgeSuccessHapticModifier(value: value))
    }
}

// MARK: - Reduce-motion-aware modifiers

private struct ForgeStaggeredAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .animation(
                ForgeMotion.animation(
                    ForgeMotion.standard.delay(ForgeMotion.staggerDelay(for: index)),
                    reduceMotion: reduceMotion
                ),
                value: isVisible
            )
    }
}

private struct ForgeAnimatedContentModifier<ID: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: ID

    func body(content: Content) -> some View {
        content
            .id(id)
            .transition(ForgeMotion.transition(ForgeMotion.appear, reduceMotion: reduceMotion))
    }
}

private struct ForgeExerciseContentModifier<ID: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: ID

    func body(content: Content) -> some View {
        content
            .id(id)
            .transition(ForgeMotion.transition(ForgeMotion.exerciseChange, reduceMotion: reduceMotion))
    }
}

private struct ForgeMetricPulseModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.changeEffect(.jump(height: 4), value: value)
        }
    }
}

private struct ForgeValidationShakeModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.changeEffect(.shake(rate: .fast), value: value)
        }
    }
}

private struct ForgeSuccessHapticModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.changeEffect(.feedback(hapticNotification: .success), value: value)
        }
    }
}
