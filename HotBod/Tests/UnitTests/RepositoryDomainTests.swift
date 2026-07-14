import XCTest
import UIKit
@testable import HotBod

// MARK: - PersistenceHelper

final class PersistenceHelperTests: XCTestCase {
    func testSaveAndLoadRoundTrip() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            struct Payload: Codable, Equatable { let value: String }
            PersistenceHelper.save(Payload(value: "hotbod"), to: "payload.json")
            let loaded = PersistenceHelper.load(Payload.self, from: "payload.json")
            XCTAssertEqual(loaded, Payload(value: "hotbod"))
        }
    }

    func testLoadMissingFileReturnsNil() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            XCTAssertNil(PersistenceHelper.load(String.self, from: "missing.json"))
        }
    }

    func testRemoveDeletesPersistedFile() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            PersistenceHelper.save("gone", to: "temp.json")
            PersistenceHelper.remove("temp.json")
            XCTAssertNil(PersistenceHelper.load(String.self, from: "temp.json"))
        }
    }

    func testCorruptJSONReturnsNil() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let url = PersistenceHelper.appSupportURL.appendingPathComponent("corrupt.json")
            try Data("{ not valid json".utf8).write(to: url)
            XCTAssertNil(PersistenceHelper.load(UserProfile.self, from: "corrupt.json"))
        }
    }

    func testLoadArrayType() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            PersistenceHelper.save([1, 2, 3], to: "ints.json")
            XCTAssertEqual(PersistenceHelper.load([Int].self, from: "ints.json"), [1, 2, 3])
        }
    }
}

// MARK: - LocalWorkoutRepository

final class LocalWorkoutRepositoryTests: XCTestCase {
    func testFetchSessionsEmptyByDefault() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalWorkoutRepository()
            let sessions = try await repo.fetchSessions()
            XCTAssertTrue(sessions.isEmpty)
        }
    }

    func testSaveAndFetchSession() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalWorkoutRepository()
            let session = FixtureBuilders.makeWorkoutSession()
            try await repo.saveSession(session)
            let fetched = try await repo.fetchSessions()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.id, session.id)
        }
    }

    func testUpdateExistingSession() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalWorkoutRepository()
            var session = FixtureBuilders.makeWorkoutSession()
            try await repo.saveSession(session)
            session.title = "Updated Title"
            try await repo.saveSession(session)
            let fetched = try await repo.fetchSessions()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.title, "Updated Title")
        }
    }

    func testTodayWorkoutSaveFetchClear() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalWorkoutRepository()
            let initial = try await repo.fetchTodayWorkout()
            XCTAssertNil(initial)

            let workout = FixtureBuilders.makeGeneratedWorkout()
            try await repo.saveTodayWorkout(workout)
            let saved = try await repo.fetchTodayWorkout()
            XCTAssertEqual(saved?.id, workout.id)

            try await repo.clearTodayWorkout()
            let cleared = try await repo.fetchTodayWorkout()
            XCTAssertNil(cleared)
        }
    }

    func testSessionSummariesOnlyIncludeCompleted() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalWorkoutRepository()
            var inProgress = FixtureBuilders.makeWorkoutSession(status: .inProgress)
            inProgress.completedAt = Date()
            try await repo.saveSession(inProgress)

            var completed = FixtureBuilders.makeWorkoutSession(status: .completed)
            completed.completedAt = Date()
            completed.exercises[0].completedSets = [
                CompletedSet(setIndex: 0, weightKg: 60, reps: 10, completedAt: Date())
            ]
            try await repo.saveSession(completed)

            let summaries = try await repo.fetchSessionSummaries()
            XCTAssertEqual(summaries.count, 1)
            XCTAssertEqual(summaries.first?.totalSets, 1)
            XCTAssertEqual(summaries.first?.totalVolumeKg ?? 0, 600, accuracy: 0.01)
        }
    }
}

// MARK: - LocalUserProfileRepository

final class LocalUserProfileRepositoryTests: XCTestCase {
    func testFetchProfileNilWhenEmpty() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalUserProfileRepository()
            let profile = try await repo.fetchProfile()
            XCTAssertNil(profile)
        }
    }

    func testSaveAndFetchProfile() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalUserProfileRepository()
            var profile = UserProfile.empty()
            profile.name = "Alex"
            try await repo.saveProfile(profile)
            let fetched = try await repo.fetchProfile()
            XCTAssertEqual(fetched?.name, "Alex")
            XCTAssertEqual(fetched?.id, profile.id)
        }
    }

    func testOnboardingDefaultsFalse() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalUserProfileRepository()
            let complete = try await repo.isOnboardingComplete()
            XCTAssertFalse(complete)
        }
    }

    func testSetOnboardingCompletePersists() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalUserProfileRepository()
            try await repo.setOnboardingComplete(true)
            let afterTrue = try await repo.isOnboardingComplete()
            XCTAssertTrue(afterTrue)
            try await repo.setOnboardingComplete(false)
            let afterFalse = try await repo.isOnboardingComplete()
            XCTAssertFalse(afterFalse)
        }
    }
}

// MARK: - LocalProgramStateRepository

final class LocalProgramStateRepositoryTests: XCTestCase {
    func testFetchDefaultStateWhenEmpty() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalProgramStateRepository()
            let state = try await repo.fetchState()
            XCTAssertEqual(state.splitDayIndex, 0)
            XCTAssertNil(state.activeSessionId)
        }
    }

    func testSaveAndFetchState() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalProgramStateRepository()
            var state = TrainingProgramState()
            state.splitDayIndex = 2
            state.activeSessionId = UUID()
            try await repo.saveState(state)
            let fetched = try await repo.fetchState()
            XCTAssertEqual(fetched.splitDayIndex, 2)
            XCTAssertEqual(fetched.activeSessionId, state.activeSessionId)
        }
    }
}

// MARK: - LocalRecoveryRepository

final class LocalRecoveryRepositoryTests: XCTestCase {
    func testFetchDefaultStatesWhenEmpty() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalRecoveryRepository()
            let states = try await repo.fetchRecoveryStates()
            XCTAssertEqual(states.count, RecoveryCalculator.defaultStates().count)
        }
    }

    func testSaveAndFetchRecoveryStates() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalRecoveryRepository()
            var states = RecoveryCalculator.defaultStates()
            states[0].recoveryPercentage = 42
            try await repo.saveRecoveryStates(states)
            let fetched = try await repo.fetchRecoveryStates()
            XCTAssertEqual(fetched.first?.recoveryPercentage, 42)
        }
    }

    func testFetchNormalizesRecoveryStates() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalRecoveryRepository()
            var states = RecoveryCalculator.defaultStates()
            states[0].recoveryPercentage = 150
            try await repo.saveRecoveryStates(states)
            let fetched = try await repo.fetchRecoveryStates()
            XCTAssertLessThanOrEqual(fetched.first?.recoveryPercentage ?? 0, 100)
        }
    }
}

// MARK: - LocalExerciseStatsRepository

final class LocalExerciseStatsRepositoryTests: XCTestCase {
    func testFetchStatsEmptyByDefault() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseStatsRepository()
            let stats = try await repo.fetchStats()
            XCTAssertTrue(stats.isEmpty)
        }
    }

    func testSaveAndFetchStats() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseStatsRepository()
            let stats = UserExerciseStats(
                exerciseId: "bench_press",
                lastWeightKg: 80,
                preferredRepRangeMin: 5,
                preferredRepRangeMax: 8
            )
            try await repo.saveStats([stats])
            let fetched = try await repo.fetchStats()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.exerciseId, "bench_press")
            XCTAssertEqual(fetched.first?.lastWeightKg, 80)
        }
    }

    func testUpdateExistingStats() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseStatsRepository()
            var stats = UserExerciseStats(
                exerciseId: "squat",
                lastWeightKg: 100,
                preferredRepRangeMin: 5,
                preferredRepRangeMax: 8
            )
            try await repo.saveStats([stats])
            stats.lastWeightKg = 105
            try await repo.saveStats([stats])
            let fetched = try await repo.fetchStats()
            XCTAssertEqual(fetched.first?.lastWeightKg, 105)
        }
    }
}

// MARK: - LocalNutritionRepository

final class LocalNutritionRepositoryTests: XCTestCase {
    func testSaveAndFetchEntryForDate() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalNutritionRepository()
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: Date())
            let entry = FixtureBuilders.makeProteinEntry(grams: 40, date: day)
            try await repo.saveEntry(entry)

            let sameDay = try await repo.fetchEntries(for: day)
            XCTAssertEqual(sameDay.count, 1)
            XCTAssertEqual(sameDay.first?.proteinGrams, 40)

            let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
            let tomorrowEntries = try await repo.fetchEntries(for: tomorrow)
            XCTAssertTrue(tomorrowEntries.isEmpty)
        }
    }

    func testFetchEntriesInRange() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalNutritionRepository()
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let mid = calendar.date(byAdding: .day, value: 2, to: start)!
            let end = calendar.date(byAdding: .day, value: 5, to: start)!

            try await repo.saveEntry(FixtureBuilders.makeProteinEntry(grams: 10, date: start))
            try await repo.saveEntry(FixtureBuilders.makeProteinEntry(grams: 20, date: mid))
            try await repo.saveEntry(FixtureBuilders.makeProteinEntry(grams: 30, date: end))

            let range = try await repo.fetchEntries(from: start, to: calendar.startOfNextDay(after: mid))
            XCTAssertEqual(range.count, 2)
            XCTAssertEqual(range.map(\.proteinGrams).sorted(), [10, 20])
        }
    }

    func testUpdateEntry() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalNutritionRepository()
            var entry = FixtureBuilders.makeProteinEntry(grams: 25)
            try await repo.saveEntry(entry)
            entry.proteinGrams = 50
            try await repo.saveEntry(entry)
            let fetched = try await repo.fetchEntries(for: entry.date)
            XCTAssertEqual(fetched.first?.proteinGrams, 50)
        }
    }

    func testDeleteEntry() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalNutritionRepository()
            let entry = FixtureBuilders.makeProteinEntry(grams: 30)
            try await repo.saveEntry(entry)
            try await repo.deleteEntry(id: entry.id)
            let fetched = try await repo.fetchEntries(for: entry.date)
            XCTAssertTrue(fetched.isEmpty)
        }
    }
}

// MARK: - LocalBodyProgressRepository

final class LocalBodyProgressRepositoryTests: XCTestCase {
    func testSaveAndFetchPhotos() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalBodyProgressRepository()
            let photo = BodyProgressPhoto(
                id: UUID(),
                userId: UUID(),
                date: Date(),
                poseType: .frontRelaxed,
                localImagePath: "/tmp/test.jpg"
            )
            try await repo.savePhoto(photo)
            let fetched = try await repo.fetchPhotos()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.id, photo.id)
        }
    }

    func testUpdatePhoto() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalBodyProgressRepository()
            var photo = BodyProgressPhoto(
                id: UUID(),
                userId: UUID(),
                date: Date(),
                poseType: .frontRelaxed,
                localImagePath: "/tmp/test.jpg"
            )
            try await repo.savePhoto(photo)
            photo.notes = "Week 4"
            try await repo.savePhoto(photo)
            let fetched = try await repo.fetchPhotos()
            XCTAssertEqual(fetched.first?.notes, "Week 4")
        }
    }

    func testDeletePhoto() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalBodyProgressRepository()
            let fileURL = repo.photosDirectory.appendingPathComponent("delete-me.jpg")
            try Data("test".utf8).write(to: fileURL)
            let photo = BodyProgressPhoto(
                id: UUID(),
                userId: UUID(),
                date: Date(),
                poseType: .sideRelaxed,
                localImagePath: fileURL.path
            )
            try await repo.savePhoto(photo)
            try await repo.deletePhoto(id: photo.id)
            let fetched = try await repo.fetchPhotos()
            XCTAssertTrue(fetched.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    func testRegression_importBodyPhotoPersistsJPEG() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            let repo = LocalBodyProgressRepository()
            let env = AppEnvironment(
                bodyProgressRepository: repo,
                bodyPhotoAnalyzer: MockBodyPhotoAnalyzer()
            )
            let userId = UUID()
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
            let image = renderer.image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
            }
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                XCTFail("Expected JPEG data")
                return
            }

            let photo = try await env.importBodyPhoto(
                imageData: data,
                userId: userId,
                pose: .frontRelaxed,
                weightKg: 80
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: photo.localImagePath))
            XCTAssertNotNil(photo.analysis)

            let fetched = await env.fetchBodyPhotos(forUserId: userId)
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.poseType, .frontRelaxed)
        }
    }

    func testRegression_realignBodyPhotoUserIdsOnAuth() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            let repo = LocalBodyProgressRepository()
            let profileRepo = LocalUserProfileRepository()
            let oldId = UUID()
            let newId = UUID()
            try await repo.savePhoto(BodyProgressPhoto(
                id: UUID(), userId: oldId, date: Date(), poseType: .frontRelaxed, localImagePath: "/tmp/a.jpg"
            ))

            let env = AppEnvironment(
                bodyProgressRepository: repo,
                userProfileRepository: profileRepo
            )
            await env.realignBodyPhotoUserIds(from: oldId, to: newId)

            let all = try await repo.fetchPhotos()
            XCTAssertEqual(all.first?.userId, newId)

            let profile = UserProfile(
                id: newId,
                goal: .buildMuscle,
                experienceLevel: .intermediate,
                trainingLocation: .commercialGym,
                availableEquipment: Equipment.allCases,
                trainingDaysPerWeek: 4,
                preferredSessionLengthMinutes: 45,
                preferredSplit: .upperLower,
                preferredTrainingDays: [.monday, .tuesday, .thursday, .friday],
                timeOfDayPreference: .flexible,
                limitations: [.none],
                proteinGoalGrams: 145,
                photoTrackingEnabled: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            env.userProfile = profile
            let visible = await env.fetchBodyPhotos()
            XCTAssertEqual(visible.count, 1)
        }
    }

    func testRegression_fetchPhotosReturnsEmptyWithoutProfile() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            let repo = LocalBodyProgressRepository()
            try await repo.savePhoto(BodyProgressPhoto(
                id: UUID(), userId: UUID(), date: Date(), poseType: .frontRelaxed, localImagePath: "/tmp/x.jpg"
            ))
            let env = AppEnvironment(bodyProgressRepository: repo)
            let photos = await env.fetchBodyPhotos()
            XCTAssertTrue(photos.isEmpty)
        }
    }

    func testRegression_fetchPhotosFiltersByUserId() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            let repo = LocalBodyProgressRepository()
            let profileRepo = LocalUserProfileRepository()
            let userA = UUID()
            let userB = UUID()
            try await repo.savePhoto(BodyProgressPhoto(
                id: UUID(), userId: userA, date: Date(), poseType: .frontRelaxed, localImagePath: "/tmp/a.jpg"
            ))
            try await repo.savePhoto(BodyProgressPhoto(
                id: UUID(), userId: userB, date: Date(), poseType: .frontRelaxed, localImagePath: "/tmp/b.jpg"
            ))

            let profile = UserProfile(
                id: userA,
                goal: .buildMuscle,
                experienceLevel: .intermediate,
                trainingLocation: .commercialGym,
                availableEquipment: Equipment.allCases,
                trainingDaysPerWeek: 4,
                preferredSessionLengthMinutes: 45,
                preferredSplit: .upperLower,
                preferredTrainingDays: [.monday, .tuesday, .thursday, .friday],
                timeOfDayPreference: .flexible,
                limitations: [.none],
                proteinGoalGrams: 145,
                photoTrackingEnabled: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await profileRepo.saveProfile(profile)

            let env = AppEnvironment(
                bodyProgressRepository: repo,
                userProfileRepository: profileRepo
            )
            env.userProfile = profile

            let photos = await env.fetchBodyPhotos()
            XCTAssertEqual(photos.count, 1)
            XCTAssertEqual(photos.first?.userId, userA)
        }
    }
}

// MARK: - LocalCoachRepository

final class LocalCoachRepositoryTests: XCTestCase {
    func testFetchMessagesEmptyByDefault() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalCoachRepository()
            let messages = try await repo.fetchMessages()
            XCTAssertTrue(messages.isEmpty)
        }
    }

    func testSaveAndFetchMessage() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalCoachRepository()
            let message = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: "Focus on progressive overload.",
                createdAt: Date(),
                intent: .modifyWorkout
            )
            try await repo.saveMessage(message)
            let fetched = try await repo.fetchMessages()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.content, message.content)
        }
    }

    func testUpdateExistingMessage() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalCoachRepository()
            var message = CoachMessage(
                id: UUID(),
                role: .user,
                content: "Make it shorter",
                createdAt: Date()
            )
            try await repo.saveMessage(message)
            message.content = "Trim accessories"
            try await repo.saveMessage(message)
            let fetched = try await repo.fetchMessages()
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.content, "Trim accessories")
        }
    }
}

// MARK: - LocalExerciseRepository preferences

final class LocalExerciseRepositoryPreferenceTests: XCTestCase {
    func testPreferenceSurvivesRepositoryReload() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseRepository()
            let exerciseId = try await repo.fetchAll().first!.id
            try await repo.updatePreference(id: exerciseId, preference: .less)

            let reloaded = LocalExerciseRepository()
            let exercise = try await reloaded.fetch(id: exerciseId)
            XCTAssertEqual(exercise?.preference, .less)
        }
    }

    func testExcludedPreferenceIsFilteredByDefault() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseRepository()
            let exerciseId = try await repo.fetchAll().first!.id
            try await repo.updatePreference(id: exerciseId, preference: .excluded)

            let filtered = try await repo.search(
                query: "",
                filters: ExerciseFilters(excludeAvoided: true)
            )
            XCTAssertFalse(filtered.contains { $0.id == exerciseId })
        }
    }

    func testResetUserPreferencesClearsPersistedOverrides() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseRepository()
            let exerciseId = try await repo.fetchAll().first!.id
            try await repo.updatePreference(id: exerciseId, preference: .favorite)
            try await repo.resetUserPreferences()

            let reloaded = LocalExerciseRepository()
            let exercise = try await reloaded.fetch(id: exerciseId)
            XCTAssertEqual(exercise?.preference, .neutral)
        }
    }
}
