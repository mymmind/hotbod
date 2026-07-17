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
                    keyboardType: keyboardType
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

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        field.textAlignment = .center
        field.keyboardType = keyboardType
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Keep the coordinator's binding current — makeCoordinator runs once.
        context.coordinator.binding = $text
        uiView.keyboardType = keyboardType

        // While this field is first responder, UIKit owns the text. Pushing the
        // binding back in mid-keystroke (or during select-all) causes lost edits
        // and cross-set resets when sibling rows re-render.
        guard !uiView.isFirstResponder else { return }
        guard uiView.text != text else { return }

        context.coordinator.isProgrammaticUpdate = true
        uiView.text = text
        context.coordinator.isProgrammaticUpdate = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var binding: Binding<String>
        var isProgrammaticUpdate = false

        init(binding: Binding<String>) {
            self.binding = binding
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            binding.wrappedValue = textField.text ?? ""
        }

        @objc func editingChanged(_ textField: UITextField) {
            guard !isProgrammaticUpdate else { return }
            binding.wrappedValue = textField.text ?? ""
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
