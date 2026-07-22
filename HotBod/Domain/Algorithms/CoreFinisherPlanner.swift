import Foundation

enum CoreRole: String, CaseIterable {
    case flexion, antiExtension, antiRotation, lateral, lowerBack
}

enum CoreFinisherPlanner {
    static let allowlist: Set<String> = [
        // existing
        "plank", "dead_bug", "bird_dog", "side_plank", "russian_twist",
        "ab_wheel_rollout", "hanging_leg_raise", "cable_crunch", "pallof_press",
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

    private static func selectFinisher(
        from candidates: [Exercise],
        planned: [PlannedExercise],
        splitDayFocus: SplitDayFocus?,
        experience: ExperienceLevel,
        exerciseStats: [UserExerciseStats]
    ) -> Exercise? {
        guard !candidates.isEmpty else { return nil }
        let preferred = preferredRole(
            for: splitDayFocus,
            planned: planned,
            exerciseStats: exerciseStats,
            candidates: candidates
        )
        let penalizeLowerBack = planned.contains { $0.exerciseId == "deadlift" || $0.exerciseId == "good_morning" }
        let statsById = statsById(from: exerciseStats)

        return candidates.sorted { lhs, rhs in
            let ls = score(lhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
            let rs = score(rhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
            if ls != rs { return ls > rs }
            return lhs.id < rhs.id
        }.first
    }

    private static func preferredRole(
        for focus: SplitDayFocus?,
        planned: [PlannedExercise],
        exerciseStats: [UserExerciseStats],
        candidates: [Exercise]
    ) -> CoreRole {
        switch focus {
        case .push, .upper: return .antiExtension
        case .pull: return .flexion
        case .legs, .lower:
            if candidates.contains(where: { role(for: $0) == .antiRotation }) {
                return .antiRotation
            }
            if candidates.contains(where: { role(for: $0) == .lowerBack }) {
                return .lowerBack
            }
            return .antiRotation
        case .fullBody, .none:
            return leastRecentlyUsedRole(exerciseStats: exerciseStats)
        }
    }

    private static func statsById(from exerciseStats: [UserExerciseStats]) -> [String: UserExerciseStats] {
        var result: [String: UserExerciseStats] = [:]
        for stat in exerciseStats where result[stat.exerciseId] == nil {
            result[stat.exerciseId] = stat
        }
        return result
    }

    private static func leastRecentlyUsedRole(exerciseStats: [UserExerciseStats]) -> CoreRole {
        var lastUsed: [CoreRole: Date] = [:]
        for stats in exerciseStats {
            guard allowlist.contains(stats.exerciseId),
                  let role = roleById[stats.exerciseId],
                  let latest = stats.recentSets.map(\.completedAt).max() else { continue }
            if let existing = lastUsed[role] {
                lastUsed[role] = max(existing, latest)
            } else {
                lastUsed[role] = latest
            }
        }
        return CoreRole.allCases.min { lhs, rhs in
            let l = lastUsed[lhs] ?? .distantPast
            let r = lastUsed[rhs] ?? .distantPast
            if l != r { return l < r }
            return lhs.rawValue < rhs.rawValue
        } ?? .antiRotation
    }

    private static func score(
        _ exercise: Exercise,
        preferred: CoreRole,
        experience: ExperienceLevel,
        penalizeLowerBack: Bool,
        statsById: [String: UserExerciseStats]
    ) -> Double {
        var value = 0.0
        let exerciseRole = role(for: exercise)
        if exerciseRole == preferred { value += 100 }
        else if compatible(preferred, exerciseRole) { value += 40 }

        if penalizeLowerBack && exerciseRole == .lowerBack { value -= 80 }

        switch (experience, exercise.difficulty) {
        case (.beginner, .advanced): value -= 50
        case (.beginner, .intermediate): value -= 15
        case (.intermediate, .advanced): value -= 10
        default: break
        }

        if let latest = statsById[exercise.id]?.recentSets.map(\.completedAt).max() {
            let days = Date().timeIntervalSince(latest) / 86_400
            if days < 3 { value -= 60 }
            else if days < 7 { value -= 30 }
        } else if let roleLast = roleLastUsed(exerciseRole, statsById: statsById) {
            let days = Date().timeIntervalSince(roleLast) / 86_400
            if days < 3 { value -= 25 }
        }

        return value
    }

    private static func roleDisplayName(_ role: CoreRole) -> String {
        switch role {
        case .flexion: "flexion"
        case .antiExtension: "anti-extension"
        case .antiRotation: "anti-rotation"
        case .lateral: "lateral"
        case .lowerBack: "lower-back"
        }
    }

    private static func compatible(_ preferred: CoreRole, _ other: CoreRole) -> Bool {
        switch preferred {
        case .antiExtension: return other == .antiRotation
        case .flexion: return other == .lateral
        case .antiRotation: return other == .lateral || other == .antiExtension
        case .lateral: return other == .antiRotation
        case .lowerBack: return other == .antiRotation
        }
    }

    private static func roleLastUsed(_ role: CoreRole, statsById: [String: UserExerciseStats]) -> Date? {
        roleById.compactMap { id, mapped -> Date? in
            guard mapped == role, let stats = statsById[id] else { return nil }
            return stats.recentSets.map(\.completedAt).max()
        }.max()
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

        let roleName = roleDisplayName(role(for: exercise))
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
