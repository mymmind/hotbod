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
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("Could you have done more reps?")
                .font(ForgeTypography.heading)
                .foregroundStyle(ForgeColors.textPrimary)

            Text("Rest is already running. This only records effort.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textSecondary)

            Spacer(minLength: ForgeSpacing.s4)

            VStack(spacing: ForgeSpacing.s2) {
                ForEach(options, id: \.value) { option in
                    choiceButton(title: option.label, identifier: "workout.rir.\(option.value)") {
                        onSelect(option.value)
                        dismiss()
                    }
                }
                choiceButton(title: "Skip", identifier: "workout.rir.skip") {
                    onSkip()
                    dismiss()
                }
            }
        }
        .padding(ForgeSpacing.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(ForgeColors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func choiceButton(title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: ForgeTarget.min)
                .padding(.horizontal, ForgeSpacing.s4)
                .background(ForgeColors.surface)
                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    ForgeRIRPromptSheet(onSelect: { _ in }, onSkip: {})
}
