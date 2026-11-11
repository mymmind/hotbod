import SwiftUI

extension SettingsView {
    @ViewBuilder
    var kettlebellCircuitSection: some View {
        if draft.availableEquipment.contains(.kettlebell) {
            SettingsComponents.section(
                title: "Kettlebell circuit",
                subtitle: "Home session from Today"
            ) {
                SettingsComponents.menuRow(
                    title: "Exercises",
                    value: "\(draft.kettlebellCircuitScheme.exerciseCount)"
                ) {
                    ForEach(KettlebellCircuitScheme.exerciseCountOptions, id: \.self) { count in
                        Button("\(count)") {
                            draft.kettlebellCircuitScheme.exerciseCount = count
                        }
                    }
                }
                SettingsComponents.divider
                SettingsComponents.menuRow(
                    title: "Reps",
                    value: "\(draft.kettlebellCircuitScheme.reps)"
                ) {
                    ForEach(KettlebellCircuitScheme.repsOptions, id: \.self) { reps in
                        Button("\(reps)") {
                            draft.kettlebellCircuitScheme.reps = reps
                        }
                    }
                }
                SettingsComponents.divider
                SettingsComponents.menuRow(
                    title: "Rounds",
                    value: "\(draft.kettlebellCircuitScheme.rounds)"
                ) {
                    ForEach(KettlebellCircuitScheme.roundsOptions, id: \.self) { rounds in
                        Button("\(rounds)") {
                            draft.kettlebellCircuitScheme.rounds = rounds
                        }
                    }
                }
                SettingsComponents.divider
                SettingsComponents.menuRow(
                    title: "In-round rest",
                    value: "\(draft.kettlebellCircuitScheme.transitionRestSeconds)s"
                ) {
                    ForEach(KettlebellCircuitScheme.transitionRestOptions, id: \.self) { seconds in
                        Button("\(seconds)s") {
                            draft.kettlebellCircuitScheme.transitionRestSeconds = seconds
                        }
                    }
                }
                SettingsComponents.divider
                SettingsComponents.menuRow(
                    title: "Between-round rest",
                    value: "\(draft.kettlebellCircuitScheme.roundRestSeconds)s"
                ) {
                    ForEach(KettlebellCircuitScheme.roundRestOptions, id: \.self) { seconds in
                        Button("\(seconds)s") {
                            draft.kettlebellCircuitScheme.roundRestSeconds = seconds
                        }
                    }
                }
                Text(
                    "Used when you start Kettlebell Circuit from Today. "
                        + "Does not change your gym day."
                )
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            }
        }
    }
}
