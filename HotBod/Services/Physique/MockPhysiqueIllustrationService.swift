import UIKit

struct MockPhysiqueIllustrationService: PhysiqueIllustrationService, Sendable {
    private let fixtureJPEG: Data

    init() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        fixtureJPEG = PhysiqueIllustrationImageCodec.jpegDataForUpload(from: image)!
    }

    func generate(
        assessmentId: UUID,
        hints: PhysiqueIllustrationHints,
        imageData: Data
    ) async throws -> Data {
        fixtureJPEG
    }
}

struct UnavailablePhysiqueIllustrationService: PhysiqueIllustrationService, Sendable {
    func generate(
        assessmentId: UUID,
        hints: PhysiqueIllustrationHints,
        imageData: Data
    ) async throws -> Data {
        throw PhysiqueIllustrationError.notConfigured
    }
}
