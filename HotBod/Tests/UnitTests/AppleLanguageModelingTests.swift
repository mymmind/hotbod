import XCTest
@testable import HotBod

@MainActor
final class AppleLanguageModelingTests: XCTestCase {
    func testMockCompleteReturnsCannedResponseWhenAvailable() async throws {
        let mock = MockAppleLanguageModeling()
        mock.cannedResponse = "hello"
        let text = try await mock.complete(prompt: "ping", kind: .onDevice)
        XCTAssertEqual(text, "hello")
        XCTAssertEqual(mock.lastPrompt, "ping")
        XCTAssertEqual(mock.lastKind, .onDevice)
    }

    func testMockCompleteThrowsWhenUnavailable() async {
        let mock = MockAppleLanguageModeling()
        mock.onDeviceAvailability = .unavailable(reason: .deviceNotEligible)
        do {
            _ = try await mock.complete(prompt: "x", kind: .onDevice)
            XCTFail("expected throw")
        } catch let AppleLanguageModelingError.unavailable(reason) {
            XCTAssertEqual(reason, .deviceNotEligible)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testMockPCCQuotaSnapshot() {
        let mock = MockAppleLanguageModeling()
        mock.pccQuota = AppleLanguageQuotaSnapshot(isLimitReached: true, resetDate: nil)
        XCTAssertEqual(mock.quota(for: .privateCloudCompute)?.isLimitReached, true)
        XCTAssertNil(mock.quota(for: .onDevice))
    }
}
