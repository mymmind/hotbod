import SwiftUI

struct ForgeCard<Content: View>: View {
    var inverted: Bool = false
    var animated: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inverted ? ForgeColors.surfaceInverse : ForgeColors.surface)
        .foregroundStyle(inverted ? ForgeColors.surface : ForgeColors.foreground)
        .overlay(
            Rectangle()
                .stroke(ForgeColors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .modifier(ForgeCardAnimationModifier(animated: animated))
    }
}

private struct ForgeCardAnimationModifier: ViewModifier {
    let animated: Bool

    func body(content: Content) -> some View {
        if animated {
            content.transition(ForgeMotion.appear)
        } else {
            content
        }
    }
}
