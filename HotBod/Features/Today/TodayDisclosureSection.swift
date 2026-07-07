import SwiftUI

struct TodayDisclosureSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s0) {
            Button {
                withAnimation(ForgeMotion.quick) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title.uppercased())
                        .font(ForgeTypography.label)
                        .tracking(ForgeTracking.eyebrow)
                        .foregroundStyle(ForgeColors.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ForgeColors.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ForgeColors.accent.opacity(0.1)))
                }
                .padding(.vertical, ForgeSpacing.s3 + 2)
                .padding(.horizontal, ForgeSpacing.s4)
            }
            .buttonStyle(.plain)
            .frame(minHeight: ForgeTarget.min)
            .contentShape(Rectangle())
            .accessibilityLabel("\(title), \(isExpanded ? "expanded" : "collapsed")")
            .accessibilityAddTraits(isExpanded ? .isSelected : [])

            if isExpanded {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ForgeSpacing.s4)
                .padding(.bottom, ForgeSpacing.s4)
                .transition(ForgeMotion.disclosureExpand)
            }
        }
        .animation(ForgeMotion.quick, value: isExpanded)
        .clipShape(RoundedRectangle.forge(ForgeRadius.soft))
        .background {
            RoundedRectangle.forge(ForgeRadius.soft)
                .fill(ForgeColors.surface)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .overlay {
            RoundedRectangle.forge(ForgeRadius.soft)
                .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
        }
    }
}
