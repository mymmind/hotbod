import Foundation

enum PhysiquePhotoAngle: String, Codable {
    case front, side, back
}

struct PhysiquePhotoSelection: Equatable {
    var front: BodyProgressPhoto
    var back: BodyProgressPhoto?
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
        guard let front = latest(matching: frontPoses, in: photos) else {
            return .missingAngles([.front])
        }

        if let failure = qualityIssue(
            for: front,
            angle: .front,
            minimumPoseConfidence: minimumPoseConfidence,
            minimumFramingScore: minimumFramingScore
        ) {
            return .qualityFailed([failure])
        }

        var back = latest(matching: backPoses, in: photos)
        if let candidate = back,
           qualityIssue(
               for: candidate,
               angle: .back,
               minimumPoseConfidence: minimumPoseConfidence,
               minimumFramingScore: minimumFramingScore
           ) != nil {
            back = nil
        }

        var side = latest(matching: sidePoses, in: photos)
        if let candidate = side,
           qualityIssue(
               for: candidate,
               angle: .side,
               minimumPoseConfidence: minimumPoseConfidence,
               minimumFramingScore: minimumFramingScore
           ) != nil {
            side = nil
        }

        return .ready(PhysiquePhotoSelection(front: front, back: back, side: side))
    }

    static func regate(
        selection: PhysiquePhotoSelection,
        minimumPoseConfidence: Double = BodyPhotoVisionMetrics.minimumPoseConfidence,
        minimumFramingScore: Double = BodyPhotoVisionMetrics.minimumFramingScore
    ) -> PhysiquePhotoGateResult {
        if let failure = qualityIssue(
            for: selection.front,
            angle: .front,
            minimumPoseConfidence: minimumPoseConfidence,
            minimumFramingScore: minimumFramingScore
        ) {
            return .qualityFailed([failure])
        }

        var backPhoto = selection.back
        if let back = selection.back,
           qualityIssue(
               for: back,
               angle: .back,
               minimumPoseConfidence: minimumPoseConfidence,
               minimumFramingScore: minimumFramingScore
           ) != nil {
            backPhoto = nil
        }

        var sidePhoto = selection.side
        if let side = selection.side,
           qualityIssue(
               for: side,
               angle: .side,
               minimumPoseConfidence: minimumPoseConfidence,
               minimumFramingScore: minimumFramingScore
           ) != nil {
            sidePhoto = nil
        }

        return .ready(
            PhysiquePhotoSelection(front: selection.front, back: backPhoto, side: sidePhoto)
        )
    }

    static func hasSide(_ selection: PhysiquePhotoSelection) -> Bool {
        selection.side != nil
    }

    static func isStale(active: PhysiqueAssessment, photos: [BodyProgressPhoto]) -> Bool {
        if let latestFront = latest(matching: frontPoses, in: photos),
           latestFront.date > active.createdAt {
            return true
        }
        if active.backPhotoId != nil,
           let latestBack = latest(matching: backPoses, in: photos),
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
