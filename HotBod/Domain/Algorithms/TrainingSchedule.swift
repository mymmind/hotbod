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
    /// Tracks whether we already advanced the split rotation for the current calendar day.
    /// This prevents double-advancing when users "restart" training and complete again.
    var todayRotationAdvancedOn: Date?
    var activeSessionId: UUID?
    var upcomingWorkout: GeneratedWorkout?
    var upcomingWorkoutFor: Date?
    var lastRecoveryDecayAppliedAt: Date?
    var weeklyRegenerationCount: Int = 0
    var regenerationWeekAnchor: Date?

    enum CodingKeys: String, CodingKey {
        case splitDayIndex, lastCompletedAt, todayCompletedSessionId, todayCompletedOn
        case todayRotationAdvancedOn, activeSessionId, upcomingWorkout, upcomingWorkoutFor
        case lastRecoveryDecayAppliedAt, weeklyRegenerationCount, regenerationWeekAnchor
    }

    init(
        splitDayIndex: Int = 0,
        lastCompletedAt: Date? = nil,
        todayCompletedSessionId: UUID? = nil,
        todayCompletedOn: Date? = nil,
        todayRotationAdvancedOn: Date? = nil,
        activeSessionId: UUID? = nil,
        upcomingWorkout: GeneratedWorkout? = nil,
        upcomingWorkoutFor: Date? = nil,
        lastRecoveryDecayAppliedAt: Date? = nil,
        weeklyRegenerationCount: Int = 0,
        regenerationWeekAnchor: Date? = nil
    ) {
        self.splitDayIndex = splitDayIndex
        self.lastCompletedAt = lastCompletedAt
        self.todayCompletedSessionId = todayCompletedSessionId
        self.todayCompletedOn = todayCompletedOn
        self.todayRotationAdvancedOn = todayRotationAdvancedOn
        self.activeSessionId = activeSessionId
        self.upcomingWorkout = upcomingWorkout
        self.upcomingWorkoutFor = upcomingWorkoutFor
        self.lastRecoveryDecayAppliedAt = lastRecoveryDecayAppliedAt
        self.weeklyRegenerationCount = weeklyRegenerationCount
        self.regenerationWeekAnchor = regenerationWeekAnchor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        splitDayIndex = try container.decodeIfPresent(Int.self, forKey: .splitDayIndex) ?? 0
        lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
        todayCompletedSessionId = try container.decodeIfPresent(UUID.self, forKey: .todayCompletedSessionId)
        todayCompletedOn = try container.decodeIfPresent(Date.self, forKey: .todayCompletedOn)
        todayRotationAdvancedOn = try container.decodeIfPresent(Date.self, forKey: .todayRotationAdvancedOn)
        activeSessionId = try container.decodeIfPresent(UUID.self, forKey: .activeSessionId)
        upcomingWorkout = try container.decodeIfPresent(GeneratedWorkout.self, forKey: .upcomingWorkout)
        upcomingWorkoutFor = try container.decodeIfPresent(Date.self, forKey: .upcomingWorkoutFor)
        lastRecoveryDecayAppliedAt = try container.decodeIfPresent(Date.self, forKey: .lastRecoveryDecayAppliedAt)
        weeklyRegenerationCount = try container.decodeIfPresent(Int.self, forKey: .weeklyRegenerationCount) ?? 0
        regenerationWeekAnchor = try container.decodeIfPresent(Date.self, forKey: .regenerationWeekAnchor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(splitDayIndex, forKey: .splitDayIndex)
        try container.encodeIfPresent(lastCompletedAt, forKey: .lastCompletedAt)
        try container.encodeIfPresent(todayCompletedSessionId, forKey: .todayCompletedSessionId)
        try container.encodeIfPresent(todayCompletedOn, forKey: .todayCompletedOn)
        try container.encodeIfPresent(todayRotationAdvancedOn, forKey: .todayRotationAdvancedOn)
        try container.encodeIfPresent(activeSessionId, forKey: .activeSessionId)
        try container.encodeIfPresent(upcomingWorkout, forKey: .upcomingWorkout)
        try container.encodeIfPresent(upcomingWorkoutFor, forKey: .upcomingWorkoutFor)
        try container.encodeIfPresent(lastRecoveryDecayAppliedAt, forKey: .lastRecoveryDecayAppliedAt)
        try container.encode(weeklyRegenerationCount, forKey: .weeklyRegenerationCount)
        try container.encodeIfPresent(regenerationWeekAnchor, forKey: .regenerationWeekAnchor)
    }
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
        let preferred = profile.reminderTrainingDays
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

    /// How many times this split day is expected inside the user's training week.
    static func exposuresPerWeek(daysPerWeek: Int, split: TrainingSplit, focus: SplitDayFocus?) -> Int {
        guard let focus else { return 1 }
        let sequence = splitSequence(for: split)
        let hits = sequence.filter { $0 == focus }.count
        guard hits > 0, !sequence.isEmpty else { return 1 }
        let days = max(daysPerWeek, sequence.count)
        let cycles = Double(days) / Double(sequence.count)
        return max(1, Int((cycles * Double(hits)).rounded()))
    }

    /// Adaptive focus: bias toward the fresher of upper vs lower musculature.
    /// Preparedness clamps at 100 within about a day, so a tie trains the region whose
    /// median muscle has gone longer without a stimulus. Never-trained muscles count as
    /// the oldest date, and one skipped muscle cannot pin the region.
    static func adaptiveFocus(recoveryStates: [MuscleRecoveryState]) -> SplitDayFocus {
        let upper = Set(muscles(for: .upper))
        let lower = Set(muscles(for: .lower))
        let upperAverage = averageRecovery(for: upper, in: recoveryStates)
        let lowerAverage = averageRecovery(for: lower, in: recoveryStates)
        if upperAverage > lowerAverage { return .upper }
        if lowerAverage > upperAverage { return .lower }
        let upperTrained = medianLastTrained(for: upper, in: recoveryStates)
        let lowerTrained = medianLastTrained(for: lower, in: recoveryStates)
        if upperTrained == lowerTrained { return .upper }
        return upperTrained < lowerTrained ? .upper : .lower
    }

    private static func averageRecovery(
        for muscles: Set<MuscleGroup>,
        in states: [MuscleRecoveryState]
    ) -> Double {
        let values = states.filter { muscles.contains($0.muscleGroup) }.map(\.recoveryPercentage)
        guard !values.isEmpty else { return 0.5 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Lower median last-trained date. `.distantPast` means most of the region is untrained.
    private static func medianLastTrained(
        for muscles: Set<MuscleGroup>,
        in states: [MuscleRecoveryState]
    ) -> Date {
        let dates = states
            .filter { muscles.contains($0.muscleGroup) }
            .map { $0.lastTrainedAt ?? .distantPast }
        guard !dates.isEmpty else { return .distantPast }
        let sorted = dates.sorted()
        return sorted[(sorted.count - 1) / 2]
    }

    /// Resolves the session focus for generation. Fixed splits use rotation; adaptive uses recovery.
    static func resolveGenerationFocus(
        state: TrainingProgramState,
        split: TrainingSplit,
        recoveryStates: [MuscleRecoveryState]
    ) -> SplitDayFocus? {
        if split == .adaptive {
            return adaptiveFocus(recoveryStates: recoveryStates)
        }
        return currentSplitFocus(state: state, split: split)
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

    static func rotationAlreadyAdvancedToday(
        state: TrainingProgramState,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let advancedOn = state.todayRotationAdvancedOn else { return false }
        return calendar.isDate(advancedOn, inSameDayAs: date)
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
        let todayStart = startOfDay(date, calendar: calendar)
        if let completedOn = state.todayCompletedOn,
           startOfDay(completedOn, calendar: calendar) < todayStart {
            state.todayCompletedSessionId = nil
            state.todayCompletedOn = nil
        }
        if let advancedOn = state.todayRotationAdvancedOn,
           startOfDay(advancedOn, calendar: calendar) < todayStart {
            state.todayRotationAdvancedOn = nil
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
