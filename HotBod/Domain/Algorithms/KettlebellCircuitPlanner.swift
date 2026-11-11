import Foundation

enum KettlebellCircuitPlanner {
    private enum Slot: CaseIterable {
        case hinge
        case squatOrLunge
        case verticalPush
        case horizontalPull
        case coreCarryAntiRotation

        func matches(_ exercise: Exercise) -> Bool {
            switch self {
            case .hinge:
                return exercise.movementPattern == .hinge
            case .squatOrLunge:
                return exercise.movementPattern == .squat || exercise.movementPattern == .lunge
            case .verticalPush:
                return exercise.movementPattern == .verticalPush
            case .horizontalPull:
                return exercise.movementPattern == .horizontalPull
            case .coreCarryAntiRotation:
                switch exercise.movementPattern {
                case .carry, .antiRotation, .rotation, .mobility, .isolation:
                    return exercise.primaryMuscles.contains(.abs)
                        || exercise.movementPattern == .carry
                        || exercise.movementPattern == .antiRotation
                        || exercise.movementPattern == .mobility
                default:
                    return false
                }
            }
        }
    }

    static func plan(
        exercises: [Exercise],
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        experience: ExperienceLevel,
        recentExerciseIds: [String],
        scheme: KettlebellCircuitScheme = .default,
        now: Date = Date()
    ) -> GeneratedWorkout? {
        let scheme = scheme.clamped
        let pool = eligiblePool(
            exercises: exercises,
            availableEquipment: availableEquipment,
            injuries: injuries
        )
        guard pool.count >= 2 else { return nil }

        let recent = Set(recentExerciseIds)
        var selected: [Exercise] = []
        var used = Set<String>()

        for slot in Slot.allCases {
            guard selected.count < scheme.exerciseCount else { break }
            if let pick = bestCandidate(
                from: pool.filter { slot.matches($0) && !used.contains($0.id) },
                experience: experience,
                recent: recent
            ) {
                selected.append(pick)
                used.insert(pick.id)
            }
        }

        let fillers = bestCandidates(
            from: pool.filter { !used.contains($0.id) },
            experience: experience,
            recent: recent,
            limit: scheme.exerciseCount - selected.count
        )
        selected.append(contentsOf: fillers)

        guard selected.count >= 2 else { return nil }
        if selected.count > scheme.exerciseCount {
            selected = Array(selected.prefix(scheme.exerciseCount))
        }

        let groupId = UUID()
        let planned = selected.enumerated().map { index, exercise in
            makePlannedExercise(exercise, orderIndex: index, groupId: groupId, scheme: scheme)
        }

        let duration = estimatedDurationMinutes(exerciseCount: planned.count, scheme: scheme)
        let names = selected.map(\.name)
        let moveWord = planned.count == 1 ? "move" : "moves"
        let rationale =
            "\(planned.count) kettlebell \(moveWord), \(scheme.reps) reps, \(scheme.rounds) rounds. "
            + "Short transitions in-round; \(scheme.roundRestSeconds) seconds between rounds."
        let focus = Array(Set(selected.flatMap(\.primaryMuscles)))
            .sorted { $0.rawValue < $1.rawValue }
        return GeneratedWorkout(
            id: UUID(),
            title: "Kettlebell Circuit",
            estimatedDurationMinutes: duration,
            focus: focus,
            exercises: planned,
            rationale: rationale,
            selectionRationale: [
                "Circuit · \(names.joined(separator: " + "))",
                "\(scheme.rounds) rounds × \(scheme.reps) reps",
                "\(scheme.transitionRestSeconds)s between moves · \(scheme.roundRestSeconds)s between rounds"
            ],
            safetyNotes: [
                "Use a weight you can keep crisp for all \(scheme.rounds) rounds.",
                "Stop a rep early if the hinge or overhead position breaks down."
            ],
            generatedBy: .rulesEngine,
            createdAt: now,
            sessionMode: .kettlebellCircuit,
            splitDayFocus: nil
        )
    }

    static func eligiblePool(
        exercises: [Exercise],
        availableEquipment: [Equipment],
        injuries: [BodyLimitation]
    ) -> [Exercise] {
        exercises.filter { exercise in
            guard exercise.equipment.contains(.kettlebell) else { return false }
            guard EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: availableEquipment) else {
                return false
            }
            guard !GenerationConstants.violatesInjuries(exercise, injuries: injuries) else { return false }
            return exercise.resolvedPrescriptionType == .reps
        }
    }

    private static func bestCandidate(
        from candidates: [Exercise],
        experience: ExperienceLevel,
        recent: Set<String>
    ) -> Exercise? {
        bestCandidates(from: candidates, experience: experience, recent: recent, limit: 1).first
    }

    private static func bestCandidates(
        from candidates: [Exercise],
        experience: ExperienceLevel,
        recent: Set<String>,
        limit: Int
    ) -> [Exercise] {
        guard limit > 0, !candidates.isEmpty else { return [] }
        let ranked = candidates.sorted { lhs, rhs in
            let left = score(lhs, experience: experience, recent: recent)
            let right = score(rhs, experience: experience, recent: recent)
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
        return Array(ranked.prefix(limit))
    }

    private static func score(
        _ exercise: Exercise,
        experience: ExperienceLevel,
        recent: Set<String>
    ) -> Double {
        var value = 10.0
        if recent.contains(exercise.id) { value -= 8 }
        if experience == .beginner, exercise.difficulty == .advanced { value -= 6 }
        if experience == .beginner, exercise.difficulty == .beginner { value += 2 }
        if experience != .beginner, exercise.difficulty == .intermediate { value += 1 }
        return value
    }

    private static func makePlannedExercise(
        _ exercise: Exercise,
        orderIndex: Int,
        groupId: UUID,
        scheme: KettlebellCircuitScheme
    ) -> PlannedExercise {
        let sets = (0..<scheme.rounds).map { _ in
            PlannedSet(
                targetRepsMin: scheme.reps,
                targetRepsMax: scheme.reps,
                rpeTarget: GenerationConstants.KettlebellCircuit.rpeTarget
            )
        }
        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: sets,
            restSeconds: scheme.roundRestSeconds,
            intensity: .moderate,
            reason: "Kettlebell circuit slot",
            groupId: groupId
        )
    }

    static func estimatedDurationMinutes(
        exerciseCount: Int,
        scheme: KettlebellCircuitScheme = .default
    ) -> Int {
        let scheme = scheme.clamped
        let work = exerciseCount * scheme.rounds * GenerationConstants.KettlebellCircuit.workSecondsPerSet
        let transitions = max(exerciseCount - 1, 0) * scheme.transitionRestSeconds * scheme.rounds
        let roundsRest = max(scheme.rounds - 1, 0) * scheme.roundRestSeconds
        let totalSeconds = work + transitions + roundsRest
        return max(Int(ceil(Double(totalSeconds) / 60.0)), 1)
    }
}
