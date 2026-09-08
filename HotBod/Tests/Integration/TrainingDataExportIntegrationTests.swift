import XCTest
@testable import HotBod

@MainActor
final class TrainingDataExportIntegrationTests: XCTestCase {
    func testMakeTrainingDataExportWritesFileOmitsNameAndSkipsIncomplete() async throws {
        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment.makeForTests(repos: repos)

        var profile = UserProfile.empty()
        profile.name = "Zara Export"
        try await env.seedOnboardedProfile(profile)

        let completedAt = Date().addingTimeInterval(-3600)
        var completed = FixtureBuilders.makeWorkoutSession(status: .completed)
        completed.title = "Export Upper"
        completed.completedAt = completedAt
        completed.startedAt = completedAt.addingTimeInterval(-2400)
        completed.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 60, reps: 8, completedAt: completedAt)
        ]
        try await env.workoutRepository.saveSession(completed)

        var incomplete = FixtureBuilders.makeWorkoutSession(status: .inProgress)
        incomplete.title = "Ghost Session"
        try await env.workoutRepository.saveSession(incomplete)

        try await env.nutritionRepository.saveEntry(
            FixtureBuilders.makeProteinEntry(grams: 40, date: Date().addingTimeInterval(-60))
        )

        let export = try await env.makeTrainingDataExport()

        XCTAssertTrue(export.markdown.contains("Export Upper"))
        XCTAssertFalse(export.markdown.contains("Zara Export"))
        XCTAssertFalse(export.markdown.contains("Ghost Session"))
        XCTAssertTrue(export.markdown.contains("40 g (goal 145)"))
        XCTAssertTrue(export.filename.hasPrefix("hotbod-training-"))
        XCTAssertTrue(export.filename.hasSuffix(".md"))
        XCTAssertEqual(export.fileURL.lastPathComponent, export.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL.path))
        let disk = try String(contentsOf: export.fileURL, encoding: .utf8)
        XCTAssertEqual(disk, export.markdown)
        XCTAssertTrue(export.markdown.contains("Not medical advice."))
    }

    func testEmptyHistoryStillExportsValidMarkdownFile() async throws {
        let env = AppEnvironment.makeForTests(repos: TestRepositories.empty())
        try await env.seedOnboardedProfile()
        let export = try await env.makeTrainingDataExport()
        XCTAssertTrue(export.markdown.contains("## Workouts"))
        XCTAssertTrue(export.markdown.contains("None logged."))
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL.path))
    }
}
