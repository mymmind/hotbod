import Foundation

/// YouTube demos keyed by exercise id. Links stay as watch URLs and play through `YouTubeEmbedPlayer`.
enum YouTubeExerciseCatalog {
    static func video(for exerciseId: String) -> ExerciseDemoVideo? {
        guard let url = videosByExerciseID[exerciseId] else { return nil }
        return ExerciseDemoVideo(
            id: "\(exerciseId)_youtube",
            angle: .front,
            url: url,
            thumbnailUrl: nil,
            durationSeconds: nil,
            isLoopable: true,
            license: .youtube
        )
    }

    private static let videosByExerciseID: [String: URL] = load()

    private static func load() -> [String: URL] {
        guard let fileURL = ExerciseCatalogLoader.resourceBundle.url(
            forResource: "YouTubeExerciseVideos",
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: fileURL),
        let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        var videos: [String: URL] = [:]
        for (exerciseId, urlString) in raw {
            guard let url = URL(string: urlString), YouTubeVideoID(url: url) != nil else { continue }
            videos[exerciseId] = url
        }
        return videos
    }
}
