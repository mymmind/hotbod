import SwiftUI

struct ForgeSetMetricField: View {
    let label: String
    @Binding var text: String
    var width: CGFloat
    var isActive: Bool
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        TextField("—", text: $text)
            .font(ForgeTypography.metric)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 10)
            .background(ForgeColors.surface)
            .overlay(
                Rectangle().stroke(
                    isActive ? ForgeColors.textPrimary : ForgeColors.border,
                    lineWidth: isActive ? ForgeBorder.emphasis : ForgeBorder.hairline
                )
            )
            .keyboardType(keyboardType)
            .accessibilityLabel(label)
            .accessibilityValue(text.isEmpty ? "empty" : text)
    }
}

#Preview {
    HStack(spacing: ForgeSpacing.s2) {
        ForgeSetMetricField(
            label: "KG",
            text: .constant("62.5"),
            width: ForgeSetTableLayout.weightFieldWidth,
            isActive: true
        )
        ForgeSetMetricField(
            label: "Reps",
            text: .constant("8"),
            width: ForgeSetTableLayout.repsFieldWidth,
            isActive: true,
            keyboardType: .numberPad
        )
    }
    .padding()
    .background(ForgeColors.background)
}

enum ForgeSetTableLayout {
    static let setNumberWidth: CGFloat = 28
    static let weightFieldWidth: CGFloat = 64
    static let repsFieldWidth: CGFloat = 52
    static let fieldSpacing: CGFloat = ForgeSpacing.s2
    static let metricsWidth: CGFloat = weightFieldWidth + fieldSpacing + repsFieldWidth
}
