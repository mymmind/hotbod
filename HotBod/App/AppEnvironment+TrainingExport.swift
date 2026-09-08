import Foundation

struct TrainingDataExport: Equatable {
    var markdown: String
    var fileURL: URL
    var filename: String
}

enum TrainingDataExportError: Error, Equatable {
    case fileWriteFailed
}

extension AppEnvironment {
    func makeTrainingDataExport(
        generatedAt: Date = Date(),
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) async throws -> TrainingDataExport {
        var profile = userProfile
        profile?.name = nil

        let sessions = ((try? await workoutRepository.fetchSessions()) ?? [])
            .filter { $0.status == .completed }
        let proteinEntries = (try? await nutritionRepository.fetchEntries(
            from: .distantPast,
            to: Date().addingTimeInterval(1)
        )) ?? []
        let fetchedRecovery = (try? await recoveryRepository.fetchRecoveryStates()) ?? []
        let recovery = fetchedRecovery.isEmpty ? recoveryStates : fetchedRecovery
        let exerciseStats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let exerciseNames = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { _, new in new })

        let snapshot = TrainingDataExportSnapshot(
            profile: profile,
            sessions: sessions,
            exerciseStats: exerciseStats,
            proteinEntries: proteinEntries,
            recovery: recovery,
            exerciseNames: exerciseNames,
            proteinGoalGrams: userProfile?.proteinGoalGrams ?? 145
        )
        let markdown = TrainingDataMarkdownExporter.render(
            snapshot,
            generatedAt: generatedAt,
            calendar: calendar
        )
        let filename = TrainingDataMarkdownExporter.filename(
            generatedAt: generatedAt,
            calendar: calendar
        )
        let directory = fileManager.temporaryDirectory
        try removePreviousTrainingExports(in: directory, fileManager: fileManager)
        let fileURL = directory.appendingPathComponent(filename)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw TrainingDataExportError.fileWriteFailed
        }
        return TrainingDataExport(markdown: markdown, fileURL: fileURL, filename: filename)
    }

    private func removePreviousTrainingExports(in directory: URL, fileManager: FileManager) throws {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("hotbod-training-")
            && url.pathExtension == "md" {
            try? fileManager.removeItem(at: url)
        }
    }
}
