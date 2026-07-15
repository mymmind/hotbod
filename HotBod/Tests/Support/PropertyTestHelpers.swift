import XCTest
@testable import HotBod

enum PropertyTestHelpers {
  static var iterationCount: Int {
    if let raw = ProcessInfo.processInfo.environment["PROPERTY_ITERATIONS"],
       let value = Int(raw), value > 0 {
      return value
    }
    return 50
  }
}

extension WorkoutGenerationInput {
  static func random(using rng: inout SeededRandomNumberGenerator) -> WorkoutGenerationInput {
    let goals = TrainingGoal.allCases
    let experiences = ExperienceLevel.allCases
    let focuses: [SplitDayFocus?] = [nil, .upper, .lower, .push, .pull, .legs, .fullBody]
    let durations = [30, 45, 60, 75]
    let sorenessLevels: [SorenessLevel] = [.none, .mild, .moderate]

    let goal = goals[Int.random(in: 0..<goals.count, using: &rng)]
    let experience = experiences[Int.random(in: 0..<experiences.count, using: &rng)]
    let focus = focuses[Int.random(in: 0..<focuses.count, using: &rng)]
    let duration = durations[Int.random(in: 0..<durations.count, using: &rng)]
    let soreness = sorenessLevels[Int.random(in: 0..<sorenessLevels.count, using: &rng)]
    let sleepScore = Double.random(in: 55...90, using: &rng)

    var profile = UserProfile.empty()
    profile.goal = goal
    profile.experienceLevel = experience
    profile.preferredSessionLengthMinutes = duration

    let recovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { muscle in
      (muscle, Double.random(in: 50...95, using: &rng))
    })

    return WorkoutGenerationInput(
      userProfile: profile,
      goal: goal,
      experienceLevel: experience,
      availableEquipment: profile.availableEquipment,
      targetDurationMinutes: duration,
      preferredMuscleGroups: [],
      avoidedMuscleGroups: [],
      injuries: [],
      recentWorkouts: [],
      muscleRecovery: recovery,
      exerciseStats: [],
      userPreferences: WorkoutPreferences(),
      readiness: ReadinessInput(sleepScore: sleepScore, soreness: soreness),
      splitDayFocus: focus
    )
  }

  func with(
    profile: UserProfile? = nil,
    injuries: [BodyLimitation]? = nil,
    equipment: [Equipment]? = nil,
    exerciseStats: [UserExerciseStats]? = nil,
    splitDayFocus: SplitDayFocus?? = nil
  ) -> WorkoutGenerationInput {
    let resolvedProfile = profile ?? userProfile
    return WorkoutGenerationInput(
      userProfile: resolvedProfile,
      goal: resolvedProfile.goal,
      experienceLevel: resolvedProfile.experienceLevel,
      availableEquipment: equipment ?? availableEquipment,
      targetDurationMinutes: targetDurationMinutes,
      preferredMuscleGroups: preferredMuscleGroups,
      avoidedMuscleGroups: avoidedMuscleGroups,
      injuries: injuries ?? self.injuries,
      recentWorkouts: recentWorkouts,
      muscleRecovery: muscleRecovery,
      exerciseStats: exerciseStats ?? self.exerciseStats,
      userPreferences: userPreferences,
      readiness: readiness,
      splitDayFocus: splitDayFocus ?? self.splitDayFocus
    )
  }
}
