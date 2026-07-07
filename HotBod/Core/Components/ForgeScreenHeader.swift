import SwiftUI

enum ForgeScreenHeaderStyle {
    case root
    case compact
}

enum ForgeScreenHeaderPresentation {
    case inline
    case sheet
}

struct ForgeScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    var style: ForgeScreenHeaderStyle = .root
    var presentation: ForgeScreenHeaderPresentation = .inline
    var eyebrow: String? = nil
    var subtitle: String? = nil
    var meta: String? = nil
    var accent: Color = ForgeColors.accent
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        style: ForgeScreenHeaderStyle = .root,
        presentation: ForgeScreenHeaderPresentation = .inline,
        eyebrow: String? = nil,
        subtitle: String? = nil,
        meta: String? = nil,
        accent: Color = ForgeColors.accent,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.style = style
        self.presentation = presentation
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.meta = meta
        self.accent = accent
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if style == .compact {
                compactBody
            } else {
                rootBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColors.background)
    }

    private var rootBody: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3 - 2) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(ForgeTypography.label)
                    .tracking(ForgeTracking.eyebrowWide)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(title)
                .font(ForgeTypography.hero)
                .foregroundStyle(ForgeColors.textPrimary)

            if subtitle != nil || meta != nil {
                HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.s3) {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
                    }

                    if let meta, !meta.isEmpty {
                        Text(meta)
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.textSecondary)
                    }
                }
            }

            accentMark
        }
        .padding(.horizontal, ForgeSpacing.s5)
        .padding(.top, ForgeSpacing.s2)
        .padding(.bottom, ForgeSpacing.s1)
        .overlay(alignment: .topTrailing) {
            trailing()
                .padding(.trailing, ForgeSpacing.s5)
                .padding(.top, ForgeSpacing.s2)
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3 - 2) {
            HStack(alignment: .center, spacing: ForgeSpacing.s3) {
                leading()
                VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(ForgeTypography.label)
                            .tracking(ForgeTracking.eyebrow)
                            .foregroundStyle(accent)
                    }
                    Text(title)
                        .font(ForgeTypography.title)
                        .foregroundStyle(ForgeColors.textPrimary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                trailing()
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(ForgeTypography.label)
                    .foregroundStyle(ForgeColors.textSecondary)
            }

            Rectangle()
                .fill(ForgeColors.border)
                .frame(height: ForgeBorder.hairline)
        }
        .padding(.horizontal, ForgeSpacing.s5)
        .padding(.top, compactTopPadding)
        .padding(.bottom, ForgeSpacing.s3)
    }

    private var compactTopPadding: CGFloat {
        presentation == .sheet ? ForgeSpacing.s5 : ForgeSpacing.s2
    }

    private var accentMark: some View {
        Rectangle()
            .fill(accent)
            .frame(width: ForgeSpacing.s12, height: 3)
    }
}

struct ForgeHeaderBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.bold))
                .foregroundStyle(ForgeColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(ForgeColors.textPrimary.opacity(0.06)))
        }
        .buttonStyle(ForgeHeaderBackButtonStyle())
        .frame(width: ForgeTarget.min, height: ForgeTarget.min)
        .contentShape(Rectangle())
        .accessibilityLabel("Back")
    }
}

private struct ForgeHeaderBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    func forgeScreenNavigationHidden() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview("Root") {
    ForgeScreenHeader(
        title: "Today",
        eyebrow: "Good morning",
        subtitle: "6 exercises lined up · ~45 min",
        trailing: {
            Image(systemName: "gearshape")
                .foregroundStyle(ForgeColors.accent)
        }
    )
}

#Preview("Compact") {
    ForgeScreenHeader(
        title: "Exercise Library",
        style: .compact,
        eyebrow: "Train",
        subtitle: "Browse and filter every movement",
        leading: { ForgeHeaderBackButton(action: {}) }
    )
}
