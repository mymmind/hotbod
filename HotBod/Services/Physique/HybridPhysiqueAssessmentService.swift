import Foundation

enum PhysiqueAssessmentError: Error, Equatable {
    case missingAngles([PhysiquePhotoAngle])
    case qualityFailed([(PhysiquePhotoAngle, String)])
    case notOnboarded

    static func == (lhs: PhysiqueAssessmentError, rhs: PhysiqueAssessmentError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAngles(let left), .missingAngles(let right)):
            left == right
        case (.qualityFailed(let left), .qualityFailed(let right)):
            left.count == right.count
                && zip(left, right).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.notOnboarded, .notOnboarded):
            true
        default:
            false
        }
    }
}

struct HybridPhysiqueAssessmentService: Sendable {
    let remote: any PhysiqueAssessmentServing
    let offline: any PhysiqueAssessmentServing
    let analyzer: any BodyPhotoAnalyzer
    let bodyProgress: (any BodyProgressRepository)?

    init(
        remote: any PhysiqueAssessmentServing,
        offline: any PhysiqueAssessmentServing,
        analyzer: any BodyPhotoAnalyzer,
        bodyProgress: (any BodyProgressRepository)? = nil
    ) {
        self.remote = remote
        self.offline = offline
        self.analyzer = analyzer
        self.bodyProgress = bodyProgress
    }

    func assess(photos: [BodyProgressPhoto], profile: UserProfile) async throws -> PhysiqueAssessment {
        switch PhysiquePhotoGate.evaluate(photos: photos) {
        case .missingAngles(let angles):
            throw PhysiqueAssessmentError.missingAngles(angles)
        case .qualityFailed(let failures):
            throw PhysiqueAssessmentError.qualityFailed(
                failures.map { ($0.angle, $0.reason) }
            )
        case .ready(let selection):
            let prepared = try await ensureMetrics(selection: selection, in: photos)
            let regated = try await regatePrepared(prepared)
            let request = PhysiqueAssessmentRequest(
                selection: regated.selection,
                frontMetrics: regated.frontMetrics,
                backMetrics: regated.backMetrics,
                sideMetrics: regated.sideMetrics,
                profile: profile
            )
            do {
                return try await remote.assess(request)
            } catch {
                return try await offline.assess(request)
            }
        }
    }

    private struct PreparedMetrics: Sendable {
        var selection: PhysiquePhotoSelection
        var frontMetrics: BodyPhotoAnalysis
        var backMetrics: BodyPhotoAnalysis?
        var sideMetrics: BodyPhotoAnalysis?
    }

    private func ensureMetrics(
        selection: PhysiquePhotoSelection,
        in photos: [BodyProgressPhoto]
    ) async throws -> PreparedMetrics {
        let front = try await ensureAnalysis(for: selection.front, in: photos)
        let back = try await selection.back.asyncMap { try await ensureAnalysis(for: $0, in: photos) }
        let side = try await selection.side.asyncMap { try await ensureAnalysis(for: $0, in: photos) }

        guard let frontMetrics = front.analysis else {
            throw PhysiqueAssessmentError.qualityFailed([(.front, "Analysis unavailable")])
        }
        if let back, back.analysis == nil {
            throw PhysiqueAssessmentError.qualityFailed([(.back, "Analysis unavailable")])
        }

        return PreparedMetrics(
            selection: PhysiquePhotoSelection(front: front, back: back, side: side),
            frontMetrics: frontMetrics,
            backMetrics: back?.analysis,
            sideMetrics: side?.analysis
        )
    }

    private func regatePrepared(_ prepared: PreparedMetrics) async throws -> PreparedMetrics {
        switch PhysiquePhotoGate.regate(selection: prepared.selection) {
        case .missingAngles(let angles):
            throw PhysiqueAssessmentError.missingAngles(angles)
        case .qualityFailed(let failures):
            throw PhysiqueAssessmentError.qualityFailed(
                failures.map { ($0.angle, $0.reason) }
            )
        case .ready(let selection):
            guard let frontMetrics = selection.front.analysis else {
                throw PhysiqueAssessmentError.qualityFailed([(.front, "Analysis unavailable")])
            }
            if let back = selection.back, back.analysis == nil {
                throw PhysiqueAssessmentError.qualityFailed([(.back, "Analysis unavailable")])
            }

            if let bodyProgress {
                try await persistAnalysisIfNeeded(for: selection.front, using: bodyProgress)
                if let back = selection.back {
                    try await persistAnalysisIfNeeded(for: back, using: bodyProgress)
                }
                if let side = selection.side {
                    try await persistAnalysisIfNeeded(for: side, using: bodyProgress)
                }
            }

            return PreparedMetrics(
                selection: selection,
                frontMetrics: frontMetrics,
                backMetrics: selection.back?.analysis,
                sideMetrics: selection.side?.analysis
            )
        }
    }

    private func persistAnalysisIfNeeded(
        for photo: BodyProgressPhoto,
        using repository: any BodyProgressRepository
    ) async throws {
        guard photo.analysis != nil else { return }
        try await repository.savePhoto(photo)
    }

    private func ensureAnalysis(
        for photo: BodyProgressPhoto,
        in photos: [BodyProgressPhoto]
    ) async throws -> BodyProgressPhoto {
        if photo.analysis != nil { return photo }
        let previous = BodyProgressPhoto.latest(
            matching: photo.poseType,
            in: photos.filter { $0.id != photo.id && $0.date < photo.date }
        )
        var updated = photo
        updated.analysis = try await analyzer.analyze(photo: photo, previous: previous)
        return updated
    }
}

private extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        switch self {
        case .none:
            return nil
        case .some(let value):
            return try await transform(value)
        }
    }
}
