import XCTest
@testable import HotBod

final class AIWorkoutServiceSelectionTests: XCTestCase {
    func testPersonalUsePrefersGeminiEvenIfSupabaseConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: true,
                supabaseConfigured: true,
                geminiConfigured: true
            ),
            .gemini
        )
    }

    func testPersonalUseFallsBackToMockWithoutGemini() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: true,
                supabaseConfigured: true,
                geminiConfigured: false
            ),
            .mock
        )
    }

    func testPersonalUseOffPrefersRemoteWhenSupabaseConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: true,
                geminiConfigured: true
            ),
            .remote
        )
    }

    func testPersonalUseOffPrefersGeminiWhenOnlyGeminiConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: false,
                geminiConfigured: true
            ),
            .gemini
        )
    }

    func testPersonalUseOffMockWhenNothingConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: false,
                geminiConfigured: false
            ),
            .mock
        )
    }
}
