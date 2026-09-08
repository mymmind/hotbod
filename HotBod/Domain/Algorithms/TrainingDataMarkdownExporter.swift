import Foundation

struct TrainingDataExportSnapshot: Equatable {
    var profile: UserProfile?
    var sessions: [WorkoutSession]
    var exerciseStats: [UserExerciseStats]
    var proteinEntries: [ProteinEntry]
    var recovery: [MuscleRecoveryState]
    var exerciseNames: [String: String]
    var proteinGoalGrams: Double
}

enum TrainingDataMarkdownExporter {
    static let disclaimer = "Not medical advice. Paste into an LLM if you want coaching on this log."
    static let noneLogged = "None logged."

    static func render(
        _ snapshot: TrainingDataExportSnapshot,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        var profile = snapshot.profile
        profile?.name = nil
        let body = [
            "# HotBod training export",
            "Generated: \(isoDate(generatedAt, calendar: calendar))",
            disclaimer,
            "",
            "## Profile",
            renderProfile(profile),
            "",
            "## Recovery (current)",
            renderRecovery(snapshot.recovery, calendar: calendar),
            "",
            "## Exercise stats",
            renderStats(snapshot.exerciseStats, names: snapshot.exerciseNames, generatedAt: generatedAt),
            "",
            "## Workouts",
            renderWorkouts(snapshot.sessions, names: snapshot.exerciseNames, calendar: calendar),
            "",
            "## Protein",
            renderProtein(
                snapshot.proteinEntries,
                goalGrams: snapshot.proteinGoalGrams,
                calendar: calendar
            )
        ]
        return body.joined(separator: "\n") + "\n"
    }

    static func filename(generatedAt: Date = Date(), calendar: Calendar = .current) -> String {
        "hotbod-training-\(isoDate(generatedAt, calendar: calendar)).md"
    }

    private static func renderProfile(_ profile: UserProfile?) -> String {
        guard let profile else { return noneLogged }
        var lines: [String] = [
            "- Goal: \(profile.goal.displayName) | Experience: \(profile.experienceLevel.displayName)",
            "- Location: \(profile.trainingLocation.displayName) | Split: \(profile.preferredSplit.displayName)"
                + " | Session: \(profile.preferredSessionLengthMinutes) min"
        ]
        if !profile.reminderTrainingDays.isEmpty {
            lines.append("- Days: \(profile.reminderTrainingDays.map(\.shortName).joined(separator: ", "))")
        }
        if !profile.availableEquipment.isEmpty {
            lines.append("- Equipment: \(profile.availableEquipment.map(\.displayName).joined(separator: ", "))")
        }
        if !profile.limitations.isEmpty {
            lines.append("- Limitations: \(profile.limitations.map(\.displayName).joined(separator: ", "))")
        }
        if let notes = profile.limitationNotes, !notes.isEmpty {
            lines.append("- Notes: \(notes)")
        }
        if let preferred = profile.preferredMuscleGroups, !preferred.isEmpty {
            lines.append("- Preferred: \(preferred.map(\.displayName).joined(separator: ", "))")
        }
        if let avoided = profile.avoidedMuscleGroups, !avoided.isEmpty {
            lines.append("- Avoided: \(avoided.map(\.displayName).joined(separator: ", "))")
        }
        lines.append("- Protein goal: \(Int(profile.proteinGoalGrams.rounded())) g")
        if let body = bodyLine(profile) {
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    private static func bodyLine(_ profile: UserProfile) -> String? {
        var parts: [String] = []
        if let age = profile.age {
            parts.append("\(age)y")
        }
        if let height = profile.heightCm {
            parts.append("\(formatNumber(height)) cm")
        }
        if let weight = profile.weightKg {
            parts.append("\(formatNumber(weight)) kg")
        }
        guard !parts.isEmpty else { return nil }
        return "- Body: \(parts.joined(separator: ", "))"
    }

    private static func renderRecovery(_ recovery: [MuscleRecoveryState], calendar: Calendar) -> String {
        guard !recovery.isEmpty else { return noneLogged }
        let rows = recovery.sorted { $0.muscleGroup.rawValue < $1.muscleGroup.rawValue }.map { state in
            let last = state.lastTrainedAt.map { isoDate($0, calendar: calendar) } ?? "—"
            let preparedness = Int(state.recoveryPercentage.rounded())
            return "| \(state.muscleGroup.displayName) | \(preparedness) | \(last) |"
        }
        return (["| Muscle | Preparedness | Last trained |"] + rows).joined(separator: "\n")
    }

    private static func renderStats(
        _ stats: [UserExerciseStats],
        names: [String: String],
        generatedAt: Date
    ) -> String {
        let lines = stats.compactMap { statsLine($0, names: names, generatedAt: generatedAt) }
            .sorted()
        return lines.isEmpty ? noneLogged : lines.joined(separator: "\n")
    }

    private static func statsLine(
        _ stats: UserExerciseStats,
        names: [String: String],
        generatedAt: Date
    ) -> String? {
        let hasSignal = stats.lastWeightKg != nil
            || stats.lastReps != nil
            || stats.estimatedOneRepMax != nil
            || !stats.recentSets.isEmpty
        guard hasSignal else { return nil }
        let name = names[stats.exerciseId] ?? stats.exerciseId
        var parts: [String] = []
        switch (stats.lastWeightKg, stats.lastReps) {
        case let (weight?, reps?):
            parts.append("last \(formatNumber(weight)) kg × \(reps)")
        case let (weight?, nil):
            parts.append("last \(formatNumber(weight)) kg")
        case let (nil, reps?):
            parts.append("last \(reps) reps")
        default:
            break
        }
        if let e1RM = stats.estimatedOneRepMax {
            parts.append("e1RM \(Int(e1RM.rounded()))")
        }
        parts.append("trend \(stats.volumeTrend.displayName)")
        var line = "- \(name): \(parts.joined(separator: ", "))"
        if stats.preferVariation {
            line += "; prefer variation"
        }
        if stats.isInDeloadWeek(at: generatedAt) {
            line += "; in deload"
        }
        return line
    }

    private static func renderWorkouts(
        _ sessions: [WorkoutSession],
        names: [String: String],
        calendar: Calendar
    ) -> String {
        let completed = sessions.filter { $0.status == .completed }.sorted { lhs, rhs in
            let left = lhs.completedAt ?? lhs.startedAt ?? .distantPast
            let right = rhs.completedAt ?? rhs.startedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        guard !completed.isEmpty else { return noneLogged }
        return completed.map { sessionBlock($0, names: names, calendar: calendar) }
            .joined(separator: "\n")
    }

    private static func sessionBlock(
        _ session: WorkoutSession,
        names: [String: String],
        calendar: Calendar
    ) -> String {
        let dateText: String
        if let date = session.completedAt ?? session.startedAt {
            dateText = isoDate(date, calendar: calendar)
        } else {
            dateText = "Unknown date"
        }
        let title = session.title.isEmpty ? "Workout" : session.title
        var lines = ["### \(dateText) — \(title)"]
        var meta: [String] = []
        meta.append("Duration \(durationMinutes(session))m")
        if let difficulty = session.perceivedDifficulty {
            meta.append("Difficulty \(difficulty)/10")
        }
        if let focus = session.splitDayFocus {
            meta.append("Focus: \(focus.displayName)")
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " | "))
        }
        if let notes = session.notes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        let exercises = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        for exercise in exercises {
            let name = names[exercise.exerciseId] ?? exercise.exerciseId
            if exercise.wasSkipped {
                if let reason = exercise.skipReason, !reason.isEmpty {
                    lines.append("- \(name): skipped — \(reason)")
                } else {
                    lines.append("- \(name): skipped")
                }
                continue
            }
            guard !exercise.completedSets.isEmpty else { continue }
            let sets = exercise.completedSets.sorted { $0.setIndex < $1.setIndex }
                .map(setToken)
                .joined(separator: ", ")
            lines.append("- \(name): \(sets)")
        }
        return lines.joined(separator: "\n")
    }

    private static func durationMinutes(_ session: WorkoutSession) -> Int {
        if let start = session.startedAt, let end = session.completedAt {
            return Int((end.timeIntervalSince(start) / 60).rounded())
        }
        return session.estimatedDurationMinutes
    }

    private static func setToken(_ set: CompletedSet) -> String {
        let core: String
        if set.reps > 0 {
            let load = set.weightKg.map(formatNumber) ?? "BW"
            core = "\(load)×\(set.reps)"
        } else if let duration = set.durationSeconds {
            if let weight = set.weightKg {
                core = "\(formatNumber(weight))×\(duration)s"
            } else {
                core = "\(duration)s"
            }
        } else if let distance = set.distanceMeters {
            core = "\(formatNumber(distance))m"
        } else {
            let load = set.weightKg.map(formatNumber) ?? "BW"
            core = "\(load)×0"
        }
        var token = core
        if let rpe = set.rpe {
            token += " @ RPE \(formatNumber(rpe))"
        }
        if let rir = set.rir {
            token += " RIR \(rir)"
        }
        if set.isWarmup { token += " (wu)" }
        if set.isCooldown { token += " (cd)" }
        if set.isFailure { token += " (fail)" }
        return token
    }

    private static func renderProtein(
        _ entries: [ProteinEntry],
        goalGrams: Double,
        calendar: Calendar
    ) -> String {
        guard !entries.isEmpty else { return noneLogged }
        var totals: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            totals[day, default: 0] += entry.proteinGrams
        }
        let goal = Int(goalGrams.rounded())
        let lines = totals.keys.sorted(by: >).map { day in
            let grams = Int((totals[day] ?? 0).rounded())
            return "- \(isoDate(day, calendar: calendar)): \(grams) g (goal \(goal))"
        }
        return lines.joined(separator: "\n")
    }

    private static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func formatNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", value)
        while text.contains("."), text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}
