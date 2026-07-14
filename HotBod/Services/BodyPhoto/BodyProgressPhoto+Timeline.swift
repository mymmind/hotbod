import Foundation

extension BodyProgressPhoto {
    static func sortedByDateDescending(_ photos: [BodyProgressPhoto]) -> [BodyProgressPhoto] {
        photos.sorted { $0.date > $1.date }
    }

    static func latest(matching pose: BodyPhotoPoseType, in photos: [BodyProgressPhoto]) -> BodyProgressPhoto? {
        photos
            .filter { $0.poseType == pose }
            .sorted { $0.date > $1.date }
            .first
    }

    static func latestPair(
        matching pose: BodyPhotoPoseType,
        in photos: [BodyProgressPhoto]
    ) -> (latest: BodyProgressPhoto, previous: BodyProgressPhoto)? {
        let matching = photos
            .filter { $0.poseType == pose }
            .sorted { $0.date > $1.date }
        guard matching.count >= 2 else { return nil }
        return (matching[0], matching[1])
    }

    static func averageLightingScore(in photos: [BodyProgressPhoto]) -> Double? {
        let scores = photos.compactMap(\.analysis?.lightingScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }
}
