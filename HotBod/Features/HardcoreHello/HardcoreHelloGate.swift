import Foundation

/// One-shot TestFlight greeting for the people actually using the app.
enum HardcoreHelloGate {
    /// Change this when a later build should show the greeting again.
    static let campaignID = "2026-10-29-matt-phil-lok"
    static let defaultsKey = "hotbod.hardcoreHello.seenCampaign"

    /// Shows on a TestFlight install that has not already dismissed this campaign.
    /// Later builds keep the stored id, so the popup does not return on every upload.
    static func shouldPresent(
        isTestFlight: Bool,
        isUITesting: Bool,
        seenCampaignID: String?
    ) -> Bool {
        isTestFlight && !isUITesting && seenCampaignID != campaignID
    }

    /// TestFlight receipts are named `sandboxReceipt`. Xcode installs also embed a
    /// provisioning profile; TestFlight builds do not.
    static func isTestFlightInstall(
        receiptFileName: String?,
        hasEmbeddedProvision: Bool
    ) -> Bool {
        receiptFileName == "sandboxReceipt" && !hasEmbeddedProvision
    }

    static var isCurrentInstallTestFlight: Bool {
        let receiptName = Bundle.main.appStoreReceiptURL?.lastPathComponent
        let hasProvision = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        return isTestFlightInstall(
            receiptFileName: receiptName,
            hasEmbeddedProvision: hasProvision
        )
    }
}

struct HardcoreHelloStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var seenCampaignID: String? {
        defaults.string(forKey: HardcoreHelloGate.defaultsKey)
    }

    func markSeen() {
        defaults.set(HardcoreHelloGate.campaignID, forKey: HardcoreHelloGate.defaultsKey)
    }
}
