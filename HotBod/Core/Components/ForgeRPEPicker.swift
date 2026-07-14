import SwiftUI

struct ForgeRPEPicker: View {
    let selection: Double?
    var rpeTarget: Double? = nil
    let onSelect: (Double) -> Void

    @State private var showHelp = false

    private let options: [Double] = [6, 7, 8, 9, 10]

    var body: some View {
        HStack(spacing: 6) {
            Button {
                showHelp = true
            } label: {
                HStack(spacing: 4) {
                    Text("RPE")
                        .font(ForgeTypography.tabLabel)
                        .tracking(ForgeTracking.tight)
                    Image(systemName: "info.circle")
                        .font(.caption2)
                }
                .foregroundStyle(ForgeColors.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What is RPE?")

            if let rpeTarget {
                Text("Target \(Int(rpeTarget))")
                    .font(ForgeTypography.tabLabel)
                    .foregroundStyle(ForgeColors.accentAmber)
            }

            ForEach(options, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    Text(String(format: "%.0f", value))
                        .font(ForgeTypography.caption)
                        .foregroundStyle(selection == value ? ForgeColors.background : ForgeColors.textPrimary)
                        .frame(minWidth: 30)
                        .padding(.vertical, 6)
                        .background(selection == value ? ForgeColors.textPrimary : ForgeColors.surface)
                        .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("RPE \(Int(value))")
                .accessibilityAddTraits(selection == value ? .isSelected : [])
                .accessibilityIdentifier("workout.rpe.\(Int(value))")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rate of perceived exertion")
        .sheet(isPresented: $showHelp) {
            ForgeRPEHelpSheet()
        }
    }
}

struct ForgeRPEHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
                    Text("RPE measures how hard a set felt on a 6–10 scale.")
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.textSecondary)

                    VStack(alignment: .leading, spacing: ForgeSpacing.s2) {
                        helpRow(rpe: 10, detail: "Max effort — no reps left")
                        helpRow(rpe: 9, detail: "1 rep in reserve")
                        helpRow(rpe: 8, detail: "2 reps in reserve")
                        helpRow(rpe: 7, detail: "3 reps in reserve")
                        helpRow(rpe: 6, detail: "4+ reps in reserve — very easy")
                    }

                    Text("HotBod uses logged RPE (and reps-in-reserve) to adjust future weight recommendations.")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
                .padding(ForgeSpacing.s5)
            }
            .background(ForgeColors.background)
            .navigationTitle("Rate of Perceived Exertion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func helpRow(rpe: Int, detail: String) -> some View {
        HStack(alignment: .top, spacing: ForgeSpacing.s3) {
            Text("\(rpe)")
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.accent)
                .frame(width: 28, alignment: .leading)
            Text(detail)
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textPrimary)
        }
    }
}

#Preview {
    ForgeRPEPicker(selection: 8, rpeTarget: 8, onSelect: { _ in })
        .padding()
        .background(ForgeColors.background)
}
