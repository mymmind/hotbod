import XCTest
@testable import HotBod

final class PersonalUseConfigTests: XCTestCase {
    override func tearDown() {
        PersonalUseConfig.isEnabledOverride = nil
        super.tearDown()
    }

    func testDefaultIsEnabled() {
        PersonalUseConfig.isEnabledOverride = nil
        XCTAssertTrue(PersonalUseConfig.isEnabled)
        XCTAssertTrue(PersonalUseConfig.defaultIsEnabled)
    }

    func testOverrideFalseDisablesPersonalUse() {
        PersonalUseConfig.isEnabledOverride = false
        XCTAssertFalse(PersonalUseConfig.isEnabled)
        XCTAssertTrue(PersonalUseConfig.shouldUseRemoteIntelligence)
        XCTAssertTrue(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: true))
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: false))
    }

    func testPersonalUseHidesAccountAndSkipsRemoteIntelligence() {
        PersonalUseConfig.isEnabledOverride = true
        XCTAssertTrue(PersonalUseConfig.isEnabled)
        XCTAssertFalse(PersonalUseConfig.shouldUseRemoteIntelligence)
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: true))
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: false))
    }

    func testUnrestrictedAccessTrueWhenPersonalUseEnabled() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = nil
        defer { SubscriptionConfig.unrestrictedAccessOverride = nil }
        XCTAssertTrue(SubscriptionConfig.unrestrictedAccess)
    }

    func testUnrestrictedAccessOverrideFalseWinsOverPersonalUse() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = false
        defer { SubscriptionConfig.unrestrictedAccessOverride = nil }
        XCTAssertFalse(SubscriptionConfig.unrestrictedAccess)
    }

    func testRegression_releaseLaunchArgsDoNotGrantPro() {
        XCTAssertTrue(PersonalUseConfig.defaultIsEnabled)
        XCTAssertFalse(
            UITestConfiguration.grantsPro(
                allowsTestOverrides: false,
                arguments: ["-UITesting", "-GrantPro"],
                environment: ["GRANT_PRO": "1"]
            )
        )
        XCTAssertTrue(
            UITestConfiguration.grantsPro(
                allowsTestOverrides: true,
                arguments: ["-GrantPro"],
                environment: [:]
            )
        )
    }
}
