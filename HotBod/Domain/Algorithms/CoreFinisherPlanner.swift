import Foundation

enum CoreRole: String, CaseIterable {
    case flexion, antiExtension, antiRotation, lateral, lowerBack
}

enum CoreFinisherPlanner {
    static let allowlist: Set<String> = [
        // existing
        "plank", "dead_bug", "bird_dog", "side_plank", "russian_twist",
        "ab_wheel_rollout", "hanging_leg_raise", "cable_crunch", "pallof_press",
        // new (Task 5 catalog)
        "crunch", "reverse_crunch", "lying_leg_raise", "hanging_knee_raise",
        "bicycle_crunch", "back_extension"
    ]

    private static let roleById: [String: CoreRole] = [
        "crunch": .flexion,
        "reverse_crunch": .flexion,
        "lying_leg_raise": .flexion,
        "hanging_knee_raise": .flexion,
        "hanging_leg_raise": .flexion,
        "cable_crunch": .flexion,
        "ab_wheel_rollout": .antiExtension,
        "plank": .antiExtension,
        "dead_bug": .antiRotation,
        "bird_dog": .antiRotation,
        "pallof_press": .antiRotation,
        "side_plank": .lateral,
        "russian_twist": .lateral,
        "bicycle_crunch": .lateral,
        "back_extension": .lowerBack
    ]

    static func appendCoreFinisher(
        to planned: inout [PlannedExercise],
        exercises: [Exercise],
        availableEquipment: [Equipment],
        experience: ExperienceLevel,
        splitDayFocus: SplitDayFocus?,
        exerciseStats: [UserExerciseStats]
    ) {
        guard !planned.isEmpty else { return }

        let existingIds = Set(planned.map(\.exerciseId))
        let candidates = exercises.filter { exercise in
            guard allowlist.contains(exercise.id) else { return false }
            guard !existingIds.contains(exercise.id) else { return false }
            guard exercise.movementPattern != .cardio else { return false }
            return EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: availableEquipment)
        }
        guard let selected = selectFinisher(
            from: candidates,
            planned: planned,
            splitDayFocus: splitDayFocus,
            experience: experience,
            exerciseStats: exerciseStats
        ) else { return }

        planned.append(buildFinisherExercise(selected, orderIndex: planned.count, experience: experience, splitDayFocus: splitDayFocus))
        for index in planned.indices {
            planned[index].orderIndex = index
        }
    }

    // Task 3 replaces this naive pick
    private static func selectFinisher(
        from candidates: [Exercise],
        planned: [PlannedExercise],
        splitDayFocus: SplitDayFocus?,
        experience: ExperienceLevel,
        exerciseStats: [UserExerciseStats]
    ) -> Exercise? {
        candidates.sorted { $0.id < $1.id }.first
    }

    private static func setCount(for experience: ExperienceLevel) -> Int {
        switch experience {
        case .beginner: 3
        case .intermediate: 4
        case .advanced: 5
        }
    }

    private static func intensity(for experience: ExperienceLevel) -> IntensityTarget {
        experience == .beginner ? .light : .moderate
    }

    private static func role(for exercise: Exercise) -> CoreRole {
        if let mapped = roleById[exercise.id] { return mapped }
        if exercise.primaryMuscles.contains(.lowerBack) { return .lowerBack }
        if exercise.movementPattern == .rotation { return .lateral }
        if exercise.movementPattern == .isolation { return .flexion }
        return .antiRotation
    }

    private static func buildFinisherExercise(
        _ exercise: Exercise,
        orderIndex: Int,
        experience: ExperienceLevel,
        splitDayFocus: SplitDayFocus?
    ) -> PlannedExercise {
        let count = setCount(for: experience)
        let prescription = ExerciseMetadataResolver.resolvedPrescriptionType(for: exercise)
        let sets: [PlannedSet]
        switch prescription {
        case .time:
            let seconds = ExerciseMetadataResolver.defaultDurationSeconds(for: exercise)
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDurationSeconds: seconds
                )
            }
        case .distance, .distanceOrTime:
            let meters = ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDistanceMeters: meters
                )
            }
        case .reps:
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 10,
                    targetRepsMax: 15,
                    rpeTarget: 7
                )
            }
        }

        let roleName = role(for: exercise).rawValue
        let focusLabel = splitDayFocus?.displayName.lowercased() ?? "session"
        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: sets,
            restSeconds: 30,
            intensity: intensity(for: experience),
            reason: "Core finisher — \(roleName) for today’s \(focusLabel)."
        )
    }
}
