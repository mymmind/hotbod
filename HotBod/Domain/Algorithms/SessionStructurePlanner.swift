import Foundation

enum CardioBlockPlacement: String, Codable, CaseIterable, Hashable {
    case none
    case start
    case end

    var displayName: String {
        switch self {
        case .none: "Off"
        case .start: "Start"
        case .end: "End"
        }
    }
}

enum CooldownSetPlanner {
    static func cooldownSets() -> [PlannedSet] {
        [
            PlannedSet(
                targetRepsMin: GenerationConstants.Cooldown.repsMin,
                targetRepsMax: GenerationConstants.Cooldown.repsMax,
                rpeTarget: GenerationConstants.Cooldown.rpeTarget,
                isCooldown: true
            )
        ]
    }
}

enum SessionStructurePlanner {
    static func appendCooldownSets(to planned: inout [PlannedExercise], exerciseMap: [String: Exercise]) {
        guard !planned.isEmpty else { return }
        let cooldown = CooldownSetPlanner.cooldownSets()
        for index in planned.indices {
            guard let exercise = exerciseMap[planned[index].exerciseId],
                  exercise.resolvedPrescriptionType == .reps else { continue }
            planned[index].targetSets.append(contentsOf: cooldown)
        }
    }

    static func applyCardioBlock(
        to planned: inout [PlannedExercise],
        placement: CardioBlockPlacement,
        exercises: [Exercise],
        availableEquipment: [Equipment],
        includeConditioning: Bool = true
    ) {
        guard includeConditioning,
              placement != .none,
              let cardio = selectCardioExercise(from: exercises, availableEquipment: availableEquipment) else {
            return
        }

        let durationSeconds = ExerciseMetadataResolver.defaultDurationSeconds(for: cardio)
        let block = PlannedExercise(
            exerciseId: cardio.id,
            orderIndex: placement == .start ? 0 : planned.count,
            targetSets: [
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: GenerationConstants.CardioBlock.rpeTarget,
                    targetDurationSeconds: durationSeconds
                )
            ],
            restSeconds: GenerationConstants.CardioBlock.restSeconds,
            intensity: .light,
            reason: placement == .start
                ? "Cardio primer to elevate heart rate before lifting."
                : "Cardio finisher for conditioning."
        )

        switch placement {
        case .none:
            break
        case .start:
            planned.insert(block, at: 0)
        case .end:
            planned.append(block)
        }

        for index in planned.indices {
            planned[index].orderIndex = index
        }
    }

    static func selectCardioExercise(
        from exercises: [Exercise],
        availableEquipment: [Equipment]
    ) -> Exercise? {
        exercises
            .filter { $0.movementPattern == .cardio }
            .filter { EquipmentFilter.isExerciseAvailable($0, availableEquipment: availableEquipment) }
            .sorted { $0.name < $1.name }
            .first
    }
}
