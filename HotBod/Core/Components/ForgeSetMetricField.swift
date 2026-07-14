import SwiftUI

struct ForgeSetMetricField: View {
    let label: String
    @Binding var text: String
    var width: CGFloat
    var isActive: Bool
    var keyboardType: UIKeyboardType = .decimalPad
    var selectAllOnFocus: Bool = false

    var body: some View {
        Group {
            if selectAllOnFocus {
                SelectAllMetricTextField(
                    text: $text,
                    keyboardType: keyboardType,
                    isActive: isActive
                )
            } else {
                TextField("—", text: $text)
                    .keyboardType(keyboardType)
            }
        }
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
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "empty" : text)
        .accessibilityAddTraits(.isButton)
    }
}

private struct SelectAllMetricTextField: UIViewRepresentable {
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isActive: Bool

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        field.textAlignment = .center
        field.keyboardType = keyboardType
        field.borderStyle = .none
        field.backgroundColor = .clear
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.keyboardType = keyboardType
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if let current = textField.text as NSString? {
                text = current.replacingCharacters(in: range, with: string)
            }
            return true
        }
    }
}

#Preview {
    HStack(spacing: ForgeSpacing.s2) {
        ForgeSetMetricField(
            label: "KG",
            text: .constant("62.5"),
            width: ForgeSetTableLayout.weightFieldWidth,
            isActive: true,
            selectAllOnFocus: true
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
    static let metricFieldWidth: CGFloat = 52
    static let fieldSpacing: CGFloat = ForgeSpacing.s2
    static let metricsWidth: CGFloat = weightFieldWidth + fieldSpacing + repsFieldWidth
}
