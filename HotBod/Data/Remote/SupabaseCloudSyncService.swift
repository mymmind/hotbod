import Foundation

#if canImport(Supabase)
import Supabase

actor SupabaseCloudSyncService: CloudSyncService {
    let client: SupabaseClient
    let auth: AuthService

    nonisolated var isAvailable: Bool { true }

    init(client: SupabaseClient, auth: AuthService) {
        self.client = client
        self.auth = auth
    }

    func requireUserId() async throws -> UUID {
        guard let id = await auth.currentUserId() else { throw SyncError.notAuthenticated }
        return id
    }

    func pullAll(local: SyncLocalStores) async throws {
        let userId = try await requireUserId()

        let profiles: [ProfileRow] = try await client.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        if let remote = profiles.first {
            let existing = try await local.userProfile.fetchProfile()
            let merged = remote.toUserProfile(fallback: existing)
            try await local.userProfile.saveProfile(merged)
            if remote.onboardingComplete == true {
                try await local.userProfile.setOnboardingComplete(true)
            }
        }

        let prefs: [UserPrefsPull] = try await client.from("user_preferences")
            .select("today_workout_json, photo_cloud_backup_enabled, program_state_json")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if let pref = prefs.first, let workout = pref.todayWorkoutJson {
            try await local.workout.saveTodayWorkout(workout)
        }
        if let pref = prefs.first, let state = pref.programStateJson {
            try await local.programState.saveState(state)
        }

        try await pullRecoveryStates(userId: userId, local: local)
        try await pullExerciseStats(userId: userId, local: local)

        let proteinRows: [ProteinEntryRow] = try await client.from("protein_entries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("entry_date", ascending: false)
            .limit(200)
            .execute()
            .value

        for row in proteinRows {
            if let entry = row.toEntry() {
                try await local.nutrition.saveEntry(entry)
            }
        }

        try await pullWorkoutSessions(userId: userId, local: local)
        try await pullBodyPhotos(userId: userId, local: local)
        try await pullCoachMessages(userId: userId, local: local)
    }

    func pushAll(local: SyncLocalStores) async throws {
        if let profile = try await local.userProfile.fetchProfile() {
            try await pushProfile(profile)
        }
        if let workout = try await local.workout.fetchTodayWorkout() {
            try await pushTodayWorkout(workout)
        }
        let sessions = try await local.workout.fetchSessions()
        for session in sessions where session.status == .completed {
            try await pushSession(session)
        }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let entries = try await local.nutrition.fetchEntries(from: start, to: Date())
        for entry in entries {
            try await pushProteinEntry(entry)
        }
        let recovery = try await local.recovery.fetchRecoveryStates()
        try await pushRecoveryStates(recovery)
        let stats = try await local.exerciseStats.fetchStats()
        try await pushExerciseStats(stats)
        let programState = try await local.programState.fetchState()
        try await pushProgramState(programState)
    }

    func pushProfile(_ profile: UserProfile) async throws {
        let userId = try await requireUserId()
        let row = ProfileRow(from: profile, userId: userId)
        try await client.from("profiles").upsert(row).execute()
    }

    func pushTodayWorkout(_ workout: GeneratedWorkout) async throws {
        let userId = try await requireUserId()
        struct PrefsPatch: Encodable {
            let today_workout_json: GeneratedWorkout
        }
        try await client.from("user_preferences")
            .update(PrefsPatch(today_workout_json: workout))
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func pushSession(_ session: WorkoutSession) async throws {
        let userId = try await requireUserId()
        let row = WorkoutSessionRow(session: session, userId: userId)
        try await client.from("workout_sessions").upsert(row).execute()

        try await client.from("workout_exercises")
            .delete()
            .eq("workout_session_id", value: session.id.uuidString)
            .execute()

        for exercise in session.exercises {
            let exRow = WorkoutExerciseRow(exercise: exercise, sessionId: session.id)
            try await client.from("workout_exercises").insert(exRow).execute()
            for set in exercise.completedSets {
                let setRow = CompletedSetRow(set: set, workoutExerciseId: exercise.id)
                try await client.from("completed_sets").upsert(setRow).execute()
            }
        }
    }

    func pushProteinEntry(_ entry: ProteinEntry) async throws {
        let userId = try await requireUserId()
        let row = ProteinEntryRow(entry: entry, userId: userId)
        try await client.from("protein_entries").upsert(row).execute()
    }

    func pushPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws {
        let userId = try await requireUserId()
        guard try await fetchPhotoBackupEnabled() else { return }

        var storagePath: String?
        if let fileData {
            let path = "\(userId.uuidString)/\(photo.id.uuidString).jpg"
            try await client.storage
                .from("body-progress")
                .upload(path, data: fileData, options: FileOptions(contentType: "image/jpeg", upsert: true))
            storagePath = path
        }

        let row = BodyPhotoRow(
            id: photo.id,
            userId: userId,
            poseType: photo.poseType.rawValue,
            storagePath: storagePath,
            weightKg: photo.weightKg,
            notes: photo.notes,
            analysisJson: photo.analysis,
            capturedAt: photo.date,
            updatedAt: Date()
        )
        try await client.from("body_progress_photos").upsert(row).execute()
    }

    func fetchPhotoBackupEnabled() async throws -> Bool {
        let userId = try await requireUserId()
        let rows: [UserPreferencesRow] = try await client.from("user_preferences")
            .select("photo_cloud_backup_enabled")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.first?.photoCloudBackupEnabled ?? false
    }

    func setPhotoBackupEnabled(_ enabled: Bool) async throws {
        let userId = try await requireUserId()
        try await client.from("user_preferences")
            .update(["photo_cloud_backup_enabled": enabled])
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func pushRecoveryStates(_ states: [MuscleRecoveryState]) async throws {
        let userId = try await requireUserId()
        for state in states {
            let row = MuscleRecoveryRow(state: state, userId: userId)
            try await client.from("muscle_recovery_states")
                .upsert(row, onConflict: "user_id,muscle_group")
                .execute()
        }
    }

    func pushExerciseStats(_ stats: [UserExerciseStats]) async throws {
        let userId = try await requireUserId()
        for stat in stats {
            let row = UserExerciseStatsRow(stat: stat, userId: userId)
            try await client.from("user_exercise_stats")
                .upsert(row, onConflict: "user_id,exercise_id")
                .execute()
        }
    }

    func pushProgramState(_ state: TrainingProgramState) async throws {
        let userId = try await requireUserId()
        struct PrefsPatch: Encodable {
            let program_state_json: TrainingProgramState
        }
        try await client.from("user_preferences")
            .update(PrefsPatch(program_state_json: state))
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}

#endif
