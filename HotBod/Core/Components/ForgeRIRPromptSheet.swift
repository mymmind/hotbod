import SwiftUI

struct ForgeRIRPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Int) -> Void
    let onSkip: () -> Void

    private let options: [(label: String, value: Int)] = [
        ("0 — Couldn't do more", 0),
        ("1 — One more rep", 1),
        ("2 — Two more reps", 2),
        ("3+ — Three or more", 4)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.s5) {
                Text("Could you have done more reps?")
                    .font(ForgeTypography.heading)
                    .foregroundStyle(ForgeColors.textPrimary)

                Text("Reps in reserve helps calibrate your next session.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.textSecondary)

                VStack(spacing: ForgeSpacing.s2) {
                    ForEach(options, id: \.value) { option in
                        Button {
                            onSelect(option.value)
                            dismiss()
                        } label: {
                            Text(option.label)
                                .font(ForgeTypography.body)
                                .foregroundStyle(ForgeColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(ForgeSpacing.s4)
                                .background(ForgeColors.surface)
                                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("workout.rir.\(option.value)")
                    }
                }

                Button("Skip") {
                    onSkip()
                    dismiss()
                }
                .font(ForgeTypography.label)
                .foregroundStyle(ForgeColors.muted)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("workout.rir.skip")
            }
            .padding(ForgeSpacing.s5)
            .background(ForgeColors.background)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ForgeRIRPromptSheet(onSelect: { _ in }, onSkip: {})
}
