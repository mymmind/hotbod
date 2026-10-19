import SwiftUI

struct ForgeSetMetricField: View {
    let label: String
    @Binding var text: String
    var width: CGFloat
    var isActive: Bool
    var keyboardType: UIKeyboardType = .decimalPad
    var selectAllOnFocus: Bool = false
    var allowsNegative: Bool = false
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if selectAllOnFocus {
                SelectAllMetricTextField(
                    text: $text,
                    keyboardType: keyboardType,
                    allowsNegative: allowsNegative,
                    onFocusChange: onFocusChange
                )
            } else {
                TextField("—", text: $text)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .onChange(of: isFocused) { _, focused in
                        onFocusChange?(focused)
                    }
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
    var allowsNegative: Bool = false
    var onFocusChange: ((Bool) -> Void)?

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
        if allowsNegative {
            field.inputAccessoryView = context.coordinator.makeAccessory(for: field)
        }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Keep the coordinator's binding current — makeCoordinator runs once.
        context.coordinator.binding = $text
        context.coordinator.onFocusChange = onFocusChange
        context.coordinator.allowsNegative = allowsNegative
        uiView.keyboardType = keyboardType
        if allowsNegative, uiView.inputAccessoryView == nil {
            uiView.inputAccessoryView = context.coordinator.makeAccessory(for: uiView)
        }

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
        Coordinator(binding: $text, allowsNegative: allowsNegative, onFocusChange: onFocusChange)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var binding: Binding<String>
        var allowsNegative: Bool
        var onFocusChange: ((Bool) -> Void)?
        var isProgrammaticUpdate = false
        private weak var field: UITextField?

        init(binding: Binding<String>, allowsNegative: Bool, onFocusChange: ((Bool) -> Void)?) {
            self.binding = binding
            self.allowsNegative = allowsNegative
            self.onFocusChange = onFocusChange
        }

        func makeAccessory(for field: UITextField) -> UIToolbar {
            self.field = field
            let bar = UIToolbar()
            let sign = UIBarButtonItem(
                title: "−",
                style: .plain,
                target: self,
                action: #selector(toggleSign)
            )
            sign.accessibilityLabel = "Toggle negative weight"
            let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let done = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
            bar.items = [sign, flex, done]
            bar.sizeToFit()
            return bar
        }

        @objc func toggleSign() {
            guard allowsNegative, let field else { return }
            var value = field.text ?? ""
            if value.hasPrefix("-") {
                value.removeFirst()
            } else {
                value = "-" + value
            }
            isProgrammaticUpdate = true
            field.text = value
            isProgrammaticUpdate = false
            binding.wrappedValue = value
        }

        @objc func dismissKeyboard() {
            field?.resignFirstResponder()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onFocusChange?(true)
            textField.selectAll(nil)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            binding.wrappedValue = textField.text ?? ""
            onFocusChange?(false)
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
