import Foundation

#if canImport(Supabase)
import Supabase

extension SupabaseCloudSyncService {
    func pullRecoveryStates(userId: UUID, local: SyncLocalStores) async throws {
        let rows: [MuscleRecoveryRow] = try await client.from("muscle_recovery_states")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        guard !rows.isEmpty else { return }
        try await local.recovery.saveRecoveryStates(rows.map(\.toState))
    }

    func pullExerciseStats(userId: UUID, local: SyncLocalStores) async throws {
        let rows: [UserExerciseStatsRow] = try await client.from("user_exercise_stats")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        guard !rows.isEmpty else { return }
        try await local.exerciseStats.saveStats(rows.map(\.toStats))
    }

    func pullWorkoutSessions(userId: UUID, local: SyncLocalStores) async throws {
        let rows: [WorkoutSessionRow] = try await client.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: WorkoutStatus.completed.rawValue)
            .order("completed_at", ascending: false)
            .limit(50)
            .execute()
            .value

        for row in rows {
            let exRows: [WorkoutExerciseRow] = try await client.from("workout_exercises")
                .select()
                .eq("workout_session_id", value: row.id.uuidString)
                .execute()
                .value

            var exercises: [WorkoutExercise] = []
            for exRow in exRows.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let setRows: [CompletedSetRow] = try await client.from("completed_sets")
                    .select()
                    .eq("workout_exercise_id", value: exRow.id.uuidString)
                    .execute()
                    .value
                let completed = setRows.map {
                    CompletedSet(
                        id: $0.id, setIndex: $0.setIndex, weightKg: $0.weightKg, reps: $0.reps,
                        rpe: $0.rpe, completedAt: $0.completedAt, isWarmup: $0.isWarmup, isFailure: $0.isFailure
                    )
                }
                exercises.append(WorkoutExercise(
                    id: exRow.id, exerciseId: exRow.exerciseId, orderIndex: exRow.orderIndex,
                    plannedSets: exRow.plannedSets, completedSets: completed,
                    restSeconds: exRow.restSeconds, notes: exRow.notes,
                    wasSkipped: exRow.wasSkipped, skipReason: exRow.skipReason
                ))
            }

            let session = WorkoutSession(
                id: row.id, userId: userId, title: row.title,
                startedAt: row.startedAt, completedAt: row.completedAt,
                estimatedDurationMinutes: row.estimatedDurationMinutes ?? 45,
                exercises: exercises, notes: row.notes,
                perceivedDifficulty: row.perceivedDifficulty,
                status: WorkoutStatus(rawValue: row.status) ?? .completed
            )
            try await local.workout.saveSession(session)
        }
    }

    func pullBodyPhotos(userId: UUID, local: SyncLocalStores) async throws {
        guard try await fetchPhotoBackupEnabled() else { return }

        let rows: [BodyPhotoRow] = try await client.from("body_progress_photos")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("captured_at", ascending: false)
            .limit(100)
            .execute()
            .value

        guard !rows.isEmpty else { return }

        let photosDir = PersistenceHelper.appSupportURL.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        for row in rows {
            var localPath = photosDir.appendingPathComponent("\(row.id.uuidString).jpg").path
            if let storagePath = row.storagePath {
                do {
                    let data = try await client.storage
                        .from("body-progress")
                        .download(path: storagePath)
                    let fileURL = photosDir.appendingPathComponent("\(row.id.uuidString).jpg")
                    try data.write(to: fileURL)
                    localPath = fileURL.path
                } catch {
                    continue
                }
            }
            let photo = row.toBodyProgressPhoto(localImagePath: localPath)
            try await local.bodyProgress.savePhoto(photo)
        }
    }

    func pullCoachMessages(userId: UUID, local: SyncLocalStores) async throws {
        let rows: [CoachMessageRow] = try await client.from("coach_messages")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .limit(200)
            .execute()
            .value

        for row in rows {
            try await local.coach.saveMessage(row.toMessage)
        }
    }
}

#endif
