import XCTest
@testable import HotBod

@MainActor
final class LaunchRouteResolverTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PersistenceHelper.configureForTesting(
            baseURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    }

    override func tearDown() {
        PersistenceHelper.clearAllPersistedData()
        PersistenceHelper.resetTestingConfiguration()
        super.tearDown()
    }

    func testInitialRouteUsesPersistedOnboardingFlag() {
        PersistenceHelper.save(true, to: "onboarding_complete.json")
        XCTAssertEqual(LaunchRouteResolver.initialRoute(), .main)

        PersistenceHelper.save(false, to: "onboarding_complete.json")
        XCTAssertEqual(LaunchRouteResolver.initialRoute(), .onboarding)
    }
}
