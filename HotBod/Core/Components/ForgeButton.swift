import SwiftUI

enum ForgeButtonStyle {
    case primary
    case inverse
    case secondary
    case accent
}

struct ForgeButton: View {
    let title: String
    var style: ForgeButtonStyle = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var accessibilityIdentifier: String? = nil
    var playsFeedback: Bool = true
    let action: () -> Void

    @Environment(\.forgeFeedback) private var feedback

    private var isInteractive: Bool { isEnabled && !isLoading }

    var body: some View {
        Button {
            if playsFeedback, style == .accent {
                feedback.play(.buttonPress)
            }
            action()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(loadingTint)
                }
                Text(title.uppercased())
                    .font(style == .accent ? ForgeTypography.cta : ForgeTypography.label)
                    .tracking(style == .accent ? ForgeTracking.cta : ForgeTracking.tight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, style == .accent ? 18 : ForgeSpacing.s4)
            .background { buttonBackground }
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle.forge(cornerRadius))
            .overlay {
                if style == .secondary {
                    RoundedRectangle.forge(cornerRadius)
                        .stroke(ForgeColors.textPrimary, lineWidth: ForgeBorder.hairline)
                }
            }
            .forgeElevation(style == .accent ? .accentButton : .none)
            .contentShape(Rectangle())
        }
        .buttonStyle(ForgePressButtonStyle())
        .disabled(!isInteractive)
        .opacity(isInteractive ? 1 : 0.4)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isLoading ? "Loading" : (isEnabled ? "" : "Disabled"))
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .accent:
            ForgeColors.accentGradient
        case .primary:
            ForgeColors.surfaceInverse
        case .inverse:
            ForgeColors.surface
        case .secondary:
            ForgeColors.surface
        }
    }

    private var cornerRadius: CGFloat {
        style == .accent ? ForgeRadius.pill : ForgeRadius.none
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .accent: ForgeColors.textOnInverse
        case .inverse, .secondary: ForgeColors.textPrimary
        }
    }

    private var loadingTint: Color {
        switch style {
        case .inverse, .secondary: ForgeColors.textPrimary
        default: ForgeColors.textOnInverse
        }
    }
}

private struct ForgePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(ForgeMotion.quick, value: configuration.isPressed)
    }
}
