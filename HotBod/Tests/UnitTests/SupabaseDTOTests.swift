import XCTest
@testable import HotBod

// MARK: - ProfileRow

final class ProfileRowTests: XCTestCase {
    func testInitFromUserProfile() {
        var profile = UserProfile.empty()
        profile.name = "Alex"
        profile.age = 30
        profile.weightKg = 82
        profile.goal = .buildMuscle
        let userId = UUID()
        let row = ProfileRow(from: profile, userId: userId)

        XCTAssertEqual(row.id, userId)
        XCTAssertEqual(row.name, "Alex")
        XCTAssertEqual(row.age, 30)
        XCTAssertEqual(row.weightKg, 82)
        XCTAssertEqual(row.goal, TrainingGoal.buildMuscle.rawValue)
        XCTAssertEqual(row.onboardingComplete, true)
    }

    func testToUserProfileRoundTripPreservesFields() {
        let profile = UserProfile.empty()
        let row = ProfileRow(from: profile, userId: profile.id)
        let restored = row.toUserProfile(fallback: nil)

        XCTAssertEqual(restored.id, profile.id)
        XCTAssertEqual(restored.goal, profile.goal)
        XCTAssertEqual(restored.experienceLevel, profile.experienceLevel)
        XCTAssertEqual(restored.trainingDaysPerWeek, profile.trainingDaysPerWeek)
        XCTAssertEqual(restored.preferredSplit, profile.preferredSplit)
    }

    func testMergeUsesFallbackForNilRemoteFields() {
        var local = UserProfile.empty()
        local.name = "Local Name"
        local.availableEquipment = [.dumbbell, .barbell]
        local.preferredTrainingDays = [.monday, .wednesday]

        let remote = ProfileRow(
            from: UserProfile.empty(),
            userId: local.id
        )
        var sparseRemote = remote
        sparseRemote.name = nil
        sparseRemote.trainingLocation = nil

        let merged = sparseRemote.toUserProfile(fallback: local)
        XCTAssertEqual(merged.name, "Local Name")
        XCTAssertEqual(merged.availableEquipment, [.dumbbell, .barbell])
        XCTAssertEqual(merged.preferredTrainingDays, [.monday, .wednesday])
    }

    func testToUserProfileRoundTripPreservesParityFields() {
        var profile = UserProfile.empty()
        profile.includeCooldown = true
        profile.preferredExerciseGrouping = .supersets
        profile.exportWorkoutsToHealthKit = true
        profile.maxAvailableWeightKg = [.dumbbell: 22]

        let row = ProfileRow(from: profile, userId: profile.id)
        let restored = row.toUserProfile(fallback: nil)

        XCTAssertTrue(restored.includeCooldown)
        XCTAssertEqual(restored.preferredExerciseGrouping, .supersets)
        XCTAssertTrue(restored.exportWorkoutsToHealthKit)
        XCTAssertEqual(restored.maxAvailableWeightKg[.dumbbell], 22)
    }

    func testWorkoutExerciseRowPreservesGroupId() {
        let groupId = UUID()
        let exercise = WorkoutExercise(
            exerciseId: "bench_press",
            orderIndex: 0,
            plannedSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)],
            groupId: groupId
        )
        let row = WorkoutExerciseRow(exercise: exercise, sessionId: UUID())
        XCTAssertEqual(row.groupId, groupId)
    }

    func testCompletedSetRowPreservesFeedbackFields() {
        let set = CompletedSet(
            setIndex: 0,
            weightKg: 80,
            reps: 8,
            rpe: 8,
            rir: 2,
            durationSeconds: 45,
            distanceMeters: 40,
            isCooldown: true
        )
        let row = CompletedSetRow(set: set, workoutExerciseId: UUID())
        XCTAssertTrue(row.isCooldown)
        XCTAssertEqual(row.rir, 2)
        XCTAssertEqual(row.durationSeconds, 45)
        XCTAssertEqual(row.distanceMeters, 40)
    }

    func testProfileRowPreservesSessionStructureToggles() {
        var profile = UserProfile.empty()
        profile.includeConditioning = true
        profile.includeCoreFinisher = false
        let row = ProfileRow(from: profile, userId: profile.id)
        let restored = row.toUserProfile(fallback: nil)
        XCTAssertTrue(restored.includeConditioning)
        XCTAssertFalse(restored.includeCoreFinisher)
    }

    func testMergePrefersRemoteValuesWhenPresent() {
        var local = UserProfile.empty()
        local.goal = .buildMuscle
        local.proteinGoalGrams = 145

        var remote = ProfileRow(from: UserProfile.empty(), userId: local.id)
        remote.goal = TrainingGoal.loseFat.rawValue
        remote.proteinGoalGrams = 180

        let merged = remote.toUserProfile(fallback: local)
        XCTAssertEqual(merged.goal, .loseFat)
        XCTAssertEqual(merged.proteinGoalGrams, 180)
    }

    func testJSONSnakeCaseDecoding() throws {
        let json = """
        {
          "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "goal": "buildMuscle",
          "experience_level": "intermediate",
          "height_cm": 180,
          "weight_kg": 80,
          "training_days_per_week": 4,
          "preferred_session_length_minutes": 45,
          "preferred_split": "upperLower",
          "protein_goal_grams": 150,
          "photo_tracking_enabled": false,
          "onboarding_complete": true
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(ProfileRow.self, from: json)
        XCTAssertEqual(row.heightCm, 180)
        XCTAssertEqual(row.weightKg, 80)
        XCTAssertEqual(row.experienceLevel, ExperienceLevel.intermediate.rawValue)
        XCTAssertEqual(row.onboardingComplete, true)
    }

    func testJSONEncodingRoundTrip() throws {
        var profile = UserProfile.empty()
        profile.heightCm = 175
        profile.weightKg = 78
        let row = ProfileRow(from: profile, userId: profile.id)
        let data = try JSONEncoder().encode(row)
        let decoded = try JSONDecoder().decode(ProfileRow.self, from: data)
        XCTAssertEqual(decoded.heightCm, 175)
        XCTAssertEqual(decoded.weightKg, 78)
    }

    func testMergeRemoteGoalOverridesLocal() {
        var local = UserProfile.empty()
        local.goal = .generalFitness
        var remote = ProfileRow(from: UserProfile.empty(), userId: local.id)
        remote.goal = TrainingGoal.loseFat.rawValue
        XCTAssertEqual(remote.toUserProfile(fallback: local).goal, .loseFat)
    }

    func testMergePartialCloudProfilePreservesEquipmentFromLocal() {
        var local = UserProfile.empty()
        local.availableEquipment = [.kettlebell, .cable]
        let remote = ProfileRow(from: UserProfile.empty(), userId: local.id)
        XCTAssertEqual(remote.toUserProfile(fallback: local).availableEquipment, [.kettlebell, .cable])
    }
}

// MARK: - ProteinEntryRow

final class ProteinEntryRowTests: XCTestCase {
    func testInitFromProteinEntry() {
        let userId = UUID()
        let entry = FixtureBuilders.makeProteinEntry(grams: 42)
        let row = ProteinEntryRow(entry: entry, userId: userId)

        XCTAssertEqual(row.id, entry.id)
        XCTAssertEqual(row.userId, userId)
        XCTAssertEqual(row.foodName, entry.foodName)
        XCTAssertEqual(row.proteinGrams, 42)
        XCTAssertEqual(row.mealType, entry.mealType.rawValue)
    }

    func testToEntryRoundTrip() {
        let entry = FixtureBuilders.makeProteinEntry(grams: 55, foodName: "Greek Yogurt")
        let row = ProteinEntryRow(entry: entry, userId: UUID())
        let restored = row.toEntry()

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, entry.id)
        XCTAssertEqual(restored?.foodName, "Greek Yogurt")
        XCTAssertEqual(restored?.proteinGrams ?? 0, 55, accuracy: 0.01)
        XCTAssertEqual(restored?.mealType, entry.mealType)
    }

    func testToEntryReturnsNilForInvalidDate() {
        let row = ProteinEntryRow(entry: FixtureBuilders.makeProteinEntry(grams: 10), userId: UUID())
        var invalid = row
        invalid.entryDate = "not-a-date"
        XCTAssertNil(invalid.toEntry())
    }

    func testJSONDecodingUsesSnakeCaseKeys() throws {
        let json = """
        {
          "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "user_id": "B2C3D4E5-F6A7-8901-BCDE-F12345678901",
          "entry_date": "2024-06-15",
          "meal_type": "lunch",
          "food_name": "Chicken",
          "protein_grams": 35,
          "source": "manual"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(ProteinEntryRow.self, from: json)
        XCTAssertEqual(row.foodName, "Chicken")
        XCTAssertEqual(row.proteinGrams, 35)
        XCTAssertEqual(row.mealType, MealType.lunch.rawValue)
        XCTAssertEqual(row.toEntry()?.proteinGrams, 35)
    }

    func testDefaultsMealTypeToSnackWhenMissing() {
        var row = ProteinEntryRow(entry: FixtureBuilders.makeProteinEntry(grams: 12), userId: UUID())
        row.mealType = nil
        XCTAssertEqual(row.toEntry()?.mealType, .snack)
    }

    func testSourceDefaultsToManual() {
        var row = ProteinEntryRow(entry: FixtureBuilders.makeProteinEntry(grams: 20), userId: UUID())
        row.source = nil
        XCTAssertEqual(row.toEntry()?.source, .manual)
    }
}

// MARK: - Other DTO mappings

final class SupabaseDTOMappingTests: XCTestCase {
    func testUserExerciseStatsRowRoundTrip() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            lastWeightKg: 120,
            estimatedOneRepMax: 160,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [100, 120]
        stats.volumeTrend = .increasing

        let row = UserExerciseStatsRow(stat: stats, userId: UUID())
        let restored = row.toStats
        XCTAssertEqual(restored.exerciseId, "squat")
        XCTAssertEqual(restored.lastWeightKg, 120)
        XCTAssertEqual(restored.weeklyVolume, [100, 120])
        XCTAssertEqual(restored.volumeTrend, .increasing)
    }

    func testUserExerciseStatsRowLegacyDeloadMigration() throws {
        let json = """
        {
          "user_id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "exercise_id": "squat",
          "preferred_rep_range_min": 5,
          "preferred_rep_range_max": 8,
          "recent_sets": [],
          "is_in_deload_week": true
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(UserExerciseStatsRow.self, from: json)
        XCTAssertNotNil(row.deloadStartedAt)
        XCTAssertTrue(row.toStats.isInDeloadWeek)
    }

    func testCoachMessageRowToMessage() {
        let id = UUID()
        let row = CoachMessageRow(
            id: id,
            userId: UUID(),
            role: CoachMessageRole.assistant.rawValue,
            content: "Deload this week.",
            intent: CoachIntent.modifyWorkout.rawValue,
            createdAt: Date()
        )
        let message = row.toMessage
        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.intent, .modifyWorkout)
    }

    func testMuscleRecoveryRowToState() {
        let row = MuscleRecoveryRow(
            state: MuscleRecoveryState(
                muscleGroup: .chest,
                recoveryPercentage: 72,
                lastTrainedAt: Date(),
                accumulatedFatigue: 12
            ),
            userId: UUID()
        )
        let state = row.toState
        XCTAssertEqual(state.muscleGroup, .chest)
        XCTAssertEqual(state.recoveryPercentage, 72)
        XCTAssertEqual(state.accumulatedFatigue, 12)
    }

    func testWorkoutSessionRowInitFromSession() {
        let session = FixtureBuilders.makeWorkoutSession(status: .completed)
        let row = WorkoutSessionRow(session: session, userId: UUID())
        XCTAssertEqual(row.id, session.id)
        XCTAssertEqual(row.title, session.title)
        XCTAssertEqual(row.status, WorkoutStatus.completed.rawValue)
    }

    func testBodyPhotoRowToBodyProgressPhoto() {
        let id = UUID()
        let userId = UUID()
        let row = BodyPhotoRow(
            id: id,
            userId: userId,
            poseType: BodyPhotoPoseType.frontRelaxed.rawValue,
            storagePath: "photos/front.jpg",
            weightKg: 80,
            notes: "Week 1",
            analysisJson: nil,
            capturedAt: Date(),
            updatedAt: Date()
        )
        let photo = row.toBodyProgressPhoto(localImagePath: "/local/front.jpg")
        XCTAssertEqual(photo.id, id)
        XCTAssertEqual(photo.userId, userId)
        XCTAssertEqual(photo.localImagePath, "/local/front.jpg")
        XCTAssertEqual(photo.poseType, .frontRelaxed)
    }
}
