import XCTest
@testable import HotBod

final class PhysiqueSplitSuggestionTests: XCTestCase {
    func testSuggestedSplitMatchesOnboardingHeuristic() {
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 3), .fullBody)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 4), .upperLower)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 5), .pushPullLegs)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 6), .pushPullLegs)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 7), .adaptive)
    }

    func testCoveragePPLBeatsFullBodyForShouldersBackAtSixDays() {
        let preferred: [MuscleGroup] = [.shoulders, .back]
        let full = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .fullBody, daysPerWeek: 6, preferred: preferred
        )
        let ppl = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .pushPullLegs, daysPerWeek: 6, preferred: preferred
        )
        XCTAssertGreaterThan(ppl, full)
    }

    func testEvaluateSuggestsPPLWhenOnFullBodySixDays() {
        let id = UUID()
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: id,
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        XCTAssertEqual(suggestion?.to, .pushPullLegs)
        XCTAssertEqual(suggestion?.from, .fullBody)
        XCTAssertEqual(suggestion?.assessmentId, id)
        XCTAssertFalse(suggestion?.highlightMuscles.isEmpty ?? true)
    }

    func testEvaluateNilWhenCandidateEqualsCurrent() {
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .pushPullLegs,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenDismissedForAssessment() {
        let id = UUID()
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: id,
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: id
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenPreferredEmptyAfterAvoided() {
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders],
            avoidedMuscleGroups: [.shoulders],
            dismissedAssessmentId: nil
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenCandidateNotBetter() {
        // Same sequence family: arnold vs PPL → equal concentration → nil
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .arnold,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        // candidate is PPL; scores equal → nil
        XCTAssertNil(suggestion)
    }

    func testAdaptiveUsesUpperLowerUnionSet() {
        let preferred: [MuscleGroup] = [.shoulders, .quads]
        let score = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .adaptive, daysPerWeek: 7, preferred: preferred
        )
        XCTAssertGreaterThan(score, 0)
    }
}
