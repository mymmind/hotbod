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
        now: Date = Date()
    ) -> GeneratedWorkout? {
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
            guard selected.count < GenerationConstants.KettlebellCircuit.exerciseCount else { break }
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
            limit: GenerationConstants.KettlebellCircuit.exerciseCount - selected.count
        )
        selected.append(contentsOf: fillers)

        guard selected.count >= 2 else { return nil }
        if selected.count > GenerationConstants.KettlebellCircuit.exerciseCount {
            selected = Array(selected.prefix(GenerationConstants.KettlebellCircuit.exerciseCount))
        }

        let groupId = UUID()
        let planned = selected.enumerated().map { index, exercise in
            makePlannedExercise(exercise, orderIndex: index, groupId: groupId)
        }

        let duration = estimatedDurationMinutes(exerciseCount: planned.count)
        let names = selected.map(\.name)
        return GeneratedWorkout(
            id: UUID(),
            title: "Kettlebell Circuit",
            estimatedDurationMinutes: duration,
            focus: Array(Set(selected.flatMap(\.primaryMuscles))).sorted { $0.rawValue < $1.rawValue },
            exercises: planned,
            rationale: "Five kettlebell moves, five reps, five rounds. Short transitions in-round; 60 seconds between rounds.",
            selectionRationale: [
                "Circuit · \(names.joined(separator: " + "))",
                "5 rounds × 5 reps",
                "15s between moves · 60s between rounds"
            ],
            safetyNotes: [
                "Use a weight you can keep crisp for all five rounds.",
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
        groupId: UUID
    ) -> PlannedExercise {
        let reps = GenerationConstants.KettlebellCircuit.reps
        let rounds = GenerationConstants.KettlebellCircuit.rounds
        let sets = (0..<rounds).map { _ in
            PlannedSet(
                targetRepsMin: reps,
                targetRepsMax: reps,
                rpeTarget: GenerationConstants.KettlebellCircuit.rpeTarget
            )
        }
        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: sets,
            restSeconds: GenerationConstants.KettlebellCircuit.roundRestSeconds,
            intensity: .moderate,
            reason: "Kettlebell circuit slot",
            groupId: groupId
        )
    }

    static func estimatedDurationMinutes(exerciseCount: Int) -> Int {
        let c = GenerationConstants.KettlebellCircuit.self
        let work = exerciseCount * c.rounds * c.workSecondsPerSet
        let transitions = max(exerciseCount - 1, 0) * c.transitionRestSeconds * c.rounds
        let roundsRest = max(c.rounds - 1, 0) * c.roundRestSeconds
        let totalSeconds = work + transitions + roundsRest
        return max(Int(ceil(Double(totalSeconds) / 60.0)), 1)
    }
}
