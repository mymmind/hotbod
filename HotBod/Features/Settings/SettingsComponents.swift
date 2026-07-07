import SwiftUI

enum SettingsComponents {
    @ViewBuilder
    static func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForgeSectionHeader(title: title, subtitle: subtitle)
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColors.surface)
            .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
        }
    }

    static var divider: some View {
        Rectangle()
            .fill(ForgeColors.border)
            .frame(height: 1)
    }

    static func valueRow(label: String, value: String, showsChevron: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(ForgeTypography.body)
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Text(value)
                    .font(ForgeTypography.monoMetric)
                    .foregroundStyle(ForgeColors.muted)
                    .multilineTextAlignment(.trailing)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }
    }

    static func menuRow<Items: View>(
        title: String,
        value: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            valueRow(label: title, value: value, showsChevron: true)
        }
    }

    static func actionRow(title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ForgeTypography.body)
                .foregroundStyle(destructive ? ForgeColors.destructive : ForgeColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    static func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(ForgeTypography.body)
        }
        .tint(ForgeColors.accent)
    }
}
