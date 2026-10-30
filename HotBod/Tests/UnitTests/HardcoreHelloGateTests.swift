import XCTest
@testable import HotBod

// UI test exemption: one-shot TestFlight greeting. UI tests launch with -UITesting,
// and HardcoreHelloGate suppresses the popup in that mode, so a UI test would never see it.
final class HardcoreHelloGateTests: XCTestCase {
    func testPresentsOnceOnTestFlightUntilThisCampaignIsDismissed() {
        XCTAssertTrue(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: true,
                isUITesting: false,
                seenCampaignID: nil
            )
        )
        XCTAssertFalse(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: true,
                isUITesting: false,
                seenCampaignID: HardcoreHelloGate.campaignID
            )
        )
    }

    func testStaysHiddenOffTestFlightAndDuringUITests() {
        XCTAssertFalse(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: false,
                isUITesting: false,
                seenCampaignID: nil
            )
        )
        XCTAssertFalse(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: true,
                isUITesting: true,
                seenCampaignID: nil
            )
        )
    }

    func testTestFlightInstallIsSandboxReceiptWithoutAProvisionProfile() {
        XCTAssertTrue(
            HardcoreHelloGate.isTestFlightInstall(
                receiptFileName: "sandboxReceipt",
                hasEmbeddedProvision: false
            )
        )
        XCTAssertFalse(
            HardcoreHelloGate.isTestFlightInstall(
                receiptFileName: "sandboxReceipt",
                hasEmbeddedProvision: true
            )
        )
        XCTAssertFalse(
            HardcoreHelloGate.isTestFlightInstall(
                receiptFileName: "receipt",
                hasEmbeddedProvision: false
            )
        )
        XCTAssertFalse(
            HardcoreHelloGate.isTestFlightInstall(
                receiptFileName: nil,
                hasEmbeddedProvision: false
            )
        )
    }

    func testStoreRemembersTheCampaign() {
        let suite = "hardcore-hello-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = HardcoreHelloStore(defaults: defaults)
        XCTAssertNil(store.seenCampaignID)
        XCTAssertTrue(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: true,
                isUITesting: false,
                seenCampaignID: store.seenCampaignID
            )
        )

        store.markSeen()
        XCTAssertEqual(store.seenCampaignID, HardcoreHelloGate.campaignID)
        XCTAssertFalse(
            HardcoreHelloGate.shouldPresent(
                isTestFlight: true,
                isUITesting: false,
                seenCampaignID: store.seenCampaignID
            )
        )
    }
}
