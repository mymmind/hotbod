import Foundation

enum SplitDayFocus: String, Codable, CaseIterable, Hashable {
    case upper
    case lower
    case push
    case pull
    case legs
    case fullBody

    var displayName: String {
        switch self {
        case .upper: "Upper"
        case .lower: "Lower"
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Legs"
        case .fullBody: "Full Body"
        }
    }
}

struct TrainingProgramState: Codable, Hashable {
    var splitDayIndex: Int = 0
    var lastCompletedAt: Date?
    var todayCompletedSessionId: UUID?
    var todayCompletedOn: Date?
    var activeSessionId: UUID?
    var upcomingWorkout: GeneratedWorkout?
    var upcomingWorkoutFor: Date?
    var lastRecoveryDecayAppliedAt: Date?
}

enum WorkoutStaleness {
    /// Workout is stale when it was not created on the current calendar day, unless a session is in flight.
    static func shouldRegenerate(
        workoutCreatedAt: Date,
        hasActiveSession: Bool,
        hasCompletedSetsToday: Bool,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        if hasActiveSession || hasCompletedSetsToday { return false }
        return !calendar.isDate(workoutCreatedAt, inSameDayAs: now)
    }
}

enum TrainingSchedule {
    static func weekday(for date: Date = Date()) -> Weekday {
        let component = Calendar.current.component(.weekday, from: date)
        return Weekday(rawValue: component) ?? .monday
    }

    static func isTrainingDay(profile: UserProfile, date: Date = Date()) -> Bool {
        let preferred = profile.preferredTrainingDays
        guard !preferred.isEmpty else {
            // No days selected = flexible schedule; user can train any day.
            return true
        }
        return preferred.contains(weekday(for: date))
    }

    static func splitSequence(for split: TrainingSplit) -> [SplitDayFocus] {
        switch split {
        case .upperLower: return [.upper, .lower]
        case .pushPullLegs: return [.push, .pull, .legs]
        case .fullBody: return [.fullBody]
        case .arnold: return [.push, .pull, .legs]
        case .adaptive: return []
        case .bodyPart:
            // Legacy body-part profiles map to PPL rotation to preserve intent.
            return [.push, .pull, .legs]
        case .custom:
            // Legacy custom split defaults to a safe full-body fallback.
            return [.fullBody]
        }
    }

    static func muscles(for focus: SplitDayFocus) -> [MuscleGroup] {
        switch focus {
        case .upper: [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: [.quads, .hamstrings, .glutes, .calves]
        case .push: [.chest, .shoulders, .triceps]
        case .pull: [.back, .biceps]
        case .legs: [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: MuscleGroup.allCases
        }
    }

    static func currentSplitFocus(state: TrainingProgramState, split: TrainingSplit) -> SplitDayFocus? {
        guard split != .adaptive else { return nil }
        let sequence = splitSequence(for: split)
        guard !sequence.isEmpty else { return .fullBody }
        return sequence[state.splitDayIndex % sequence.count]
    }

    static func advanceRotation(state: inout TrainingProgramState, split: TrainingSplit) {
        guard split != .adaptive else {
            state.lastCompletedAt = Date()
            return
        }
        let count = max(1, splitSequence(for: split).count)
        state.splitDayIndex = (state.splitDayIndex + 1) % count
        state.lastCompletedAt = Date()
    }

    /// Advances split rotation only when the completed session matched the current rotation head.
    static func advanceRotationIfMatchingFocus(
        state: inout TrainingProgramState,
        split: TrainingSplit,
        completedFocus: SplitDayFocus?
    ) {
        guard split != .adaptive else {
            state.lastCompletedAt = Date()
            return
        }
        guard let currentFocus = currentSplitFocus(state: state, split: split) else {
            state.lastCompletedAt = Date()
            return
        }
        // Legacy sessions without splitDayFocus are treated as matching the rotation head.
        let effectiveFocus = completedFocus ?? currentFocus
        guard effectiveFocus == currentFocus else {
            state.lastCompletedAt = Date()
            return
        }
        advanceRotation(state: &state, split: split)
    }

    static func clearLegacyUpcomingWorkout(state: inout TrainingProgramState) {
        state.upcomingWorkout = nil
        state.upcomingWorkoutFor = nil
    }

    static func toggleSplitFocus(state: inout TrainingProgramState, split: TrainingSplit) {
        guard split != .adaptive else { return }
        let count = max(1, splitSequence(for: split).count)
        guard count > 1 else { return }
        state.splitDayIndex = (state.splitDayIndex + 1) % count
    }

    static func nextSplitFocus(after focus: SplitDayFocus, split: TrainingSplit) -> SplitDayFocus? {
        let sequence = splitSequence(for: split)
        guard sequence.count > 1, let index = sequence.firstIndex(of: focus) else { return nil }
        return sequence[(index + 1) % sequence.count]
    }

    static func nextTrainingDate(profile: UserProfile, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if isTrainingDay(profile: profile, date: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func nextTrainingDayLabel(profile: UserProfile, from date: Date = Date()) -> String? {
        guard let next = nextTrainingDate(profile: profile, from: date) else { return nil }
        let day = weekday(for: next)
        return day.shortName
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isTodayWorkoutCompleted(state: TrainingProgramState, date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let completedOn = state.todayCompletedOn else { return false }
        return calendar.isDate(completedOn, inSameDayAs: date)
    }

    static func isUpcomingWorkoutValid(
        state: TrainingProgramState,
        profile: UserProfile,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let workout = state.upcomingWorkout,
              let scheduledFor = state.upcomingWorkoutFor,
              isTrainingDay(profile: profile, date: date) else { return false }
        return calendar.isDate(scheduledFor, inSameDayAs: date) && workout.createdAt <= date
    }

    static func clearStaleCompletion(state: inout TrainingProgramState, date: Date = Date(), calendar: Calendar = .current) {
        guard let completedOn = state.todayCompletedOn else { return }
        if !calendar.isDate(completedOn, inSameDayAs: date) {
            state.todayCompletedSessionId = nil
            state.todayCompletedOn = nil
        }
    }

    static func clearExpiredUpcomingWorkout(state: inout TrainingProgramState, date: Date = Date(), calendar: Calendar = .current) {
        guard let scheduledFor = state.upcomingWorkoutFor else { return }
        if scheduledFor < startOfDay(date, calendar: calendar) {
            state.upcomingWorkout = nil
            state.upcomingWorkoutFor = nil
        }
    }
}
