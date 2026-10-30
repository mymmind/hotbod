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
            Text("HELLO")
                .font(ForgeTypography.label)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accent)
            names
            Text("You three are the whole user list. This shows once.")
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

    private var names: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Matt.")
            Text("Phil.")
            Text("Lok.")
        }
        .font(ForgeTypography.hero)
        .foregroundStyle(ForgeColors.textPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Matt, Phil, and Lok")
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
