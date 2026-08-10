import Foundation

enum PhysiquePhotoAngle: String, Codable {
    case front, side, back
}

struct PhysiquePhotoSelection: Equatable {
    var front: BodyProgressPhoto
    var back: BodyProgressPhoto
    var side: BodyProgressPhoto?
}

enum PhysiquePhotoGateResult: Equatable {
    case ready(PhysiquePhotoSelection)
    case missingAngles([PhysiquePhotoAngle])
    case qualityFailed([(angle: PhysiquePhotoAngle, reason: String)])

    static func == (lhs: PhysiquePhotoGateResult, rhs: PhysiquePhotoGateResult) -> Bool {
        switch (lhs, rhs) {
        case (.ready(let left), .ready(let right)):
            left == right
        case (.missingAngles(let left), .missingAngles(let right)):
            left == right
        case (.qualityFailed(let left), .qualityFailed(let right)):
            left.count == right.count
                && zip(left, right).allSatisfy { $0.angle == $1.angle && $0.reason == $1.reason }
        default:
            false
        }
    }
}

enum PhysiquePhotoGate {
    private static let frontPoses: [BodyPhotoPoseType] = [.frontRelaxed, .frontFlexed]
    private static let backPoses: [BodyPhotoPoseType] = [.backRelaxed, .backFlexed]
    private static let sidePoses: [BodyPhotoPoseType] = [.sideRelaxed, .sideFlexed]

    static func evaluate(
        photos: [BodyProgressPhoto],
        minimumPoseConfidence: Double = BodyPhotoVisionMetrics.minimumPoseConfidence,
        minimumFramingScore: Double = BodyPhotoVisionMetrics.minimumFramingScore
    ) -> PhysiquePhotoGateResult {
        var missing: [PhysiquePhotoAngle] = []

        let front = latest(matching: frontPoses, in: photos)
        if front == nil {
            missing.append(.front)
        }

        let back = latest(matching: backPoses, in: photos)
        if back == nil {
            missing.append(.back)
        }

        if !missing.isEmpty {
            return .missingAngles(missing)
        }

        guard let front, let back else {
            return .missingAngles([.front, .back])
        }

        let side = latest(matching: sidePoses, in: photos)

        var qualityFailures: [(angle: PhysiquePhotoAngle, reason: String)] = []
        if let failure = qualityIssue(
            for: front,
            angle: .front,
            minimumPoseConfidence: minimumPoseConfidence,
            minimumFramingScore: minimumFramingScore
        ) {
            qualityFailures.append(failure)
        }
        if let failure = qualityIssue(
            for: back,
            angle: .back,
            minimumPoseConfidence: minimumPoseConfidence,
            minimumFramingScore: minimumFramingScore
        ) {
            qualityFailures.append(failure)
        }
        if let side, let failure = qualityIssue(
            for: side,
            angle: .side,
            minimumPoseConfidence: minimumPoseConfidence,
            minimumFramingScore: minimumFramingScore
        ) {
            qualityFailures.append(failure)
        }

        if !qualityFailures.isEmpty {
            return .qualityFailed(qualityFailures)
        }

        return .ready(PhysiquePhotoSelection(front: front, back: back, side: side))
    }

    static func hasSide(_ selection: PhysiquePhotoSelection) -> Bool {
        selection.side != nil
    }

    static func isStale(active: PhysiqueAssessment, photos: [BodyProgressPhoto]) -> Bool {
        if let latestFront = latest(matching: frontPoses, in: photos),
           latestFront.date > active.createdAt {
            return true
        }
        if let latestBack = latest(matching: backPoses, in: photos),
           latestBack.date > active.createdAt {
            return true
        }
        return false
    }

    private static func latest(
        matching poses: [BodyPhotoPoseType],
        in photos: [BodyProgressPhoto]
    ) -> BodyProgressPhoto? {
        photos
            .filter { poses.contains($0.poseType) }
            .max(by: { $0.date < $1.date })
    }

    private static func qualityIssue(
        for photo: BodyProgressPhoto,
        angle: PhysiquePhotoAngle,
        minimumPoseConfidence: Double,
        minimumFramingScore: Double
    ) -> (angle: PhysiquePhotoAngle, reason: String)? {
        guard let analysis = photo.analysis else { return nil }
        if analysis.poseConfidence < minimumPoseConfidence {
            return (angle, "Pose confidence too low")
        }
        if analysis.framingScore < minimumFramingScore {
            return (angle, "Framing score too low")
        }
        return nil
    }
}
