import SwiftUI

struct HardcoreHelloView: View {
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var catGIF: Data?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
            card
                .padding(.horizontal, ForgeSpacing.s6)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("hardcoreHello")
        .task { loadCat() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s5) {
            Text("Yo Matt, Phil and Lok!")
                .font(ForgeTypography.hero)
                .foregroundStyle(ForgeColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Quit twiddling your nuts and get to work.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            cat
            ForgeButton(
                title: "Got it",
                style: .accent,
                accessibilityIdentifier: "hardcoreHelloDismiss",
                action: onDismiss
            )
        }
        .padding(ForgeSpacing.s6)
        .frame(maxWidth: 420, alignment: .leading)
        .background(ForgeColors.surface)
        .overlay(Rectangle().stroke(ForgeColors.textPrimary, lineWidth: ForgeBorder.emphasis))
    }

    @ViewBuilder
    private var cat: some View {
        if let catGIF {
            LoopingGIFView(data: catGIF, animates: !reduceMotion)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
                .accessibilityHidden(false)
        }
    }

    private func loadCat() {
        guard catGIF == nil else { return }
        guard let url = Bundle.main.url(forResource: "LaughingCat", withExtension: "gif") else { return }
        catGIF = try? Data(contentsOf: url)
    }
}

#Preview("Hardcore hello") {
    HardcoreHelloView(onDismiss: {})
        .preferredColorScheme(.dark)
}
