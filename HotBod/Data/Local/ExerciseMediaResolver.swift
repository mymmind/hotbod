import Foundation

enum ExerciseMediaResolver {
    static let bundledScheme = "hotbod-bundled"

    private static let bundledResourceNames: [String: String] = [
        "bench_press": "bench_press_demo",
        "squat": "squat_demo",
        "deadlift": "deadlift_demo"
    ]

    static func resolvePlaybackURL(for video: ExerciseDemoVideo) -> URL? {
        if video.url.scheme == bundledScheme {
            let resource = video.url.host ?? video.url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return bundleURL(for: resource)
        }
        if video.url.isFileURL {
            return FileManager.default.fileExists(atPath: video.url.path) ? video.url : nil
        }
        if let scheme = video.url.scheme, scheme == "http" || scheme == "https" {
            return video.url
        }
        return nil
    }

    static func bundledFallback(for exerciseId: String) -> ExerciseDemoVideo? {
        guard let resource = bundledResourceNames[exerciseId],
              bundleURL(for: resource) != nil else { return nil }
        return ExerciseDemoVideo(
            id: "\(exerciseId)_bundled",
            angle: .front,
            url: URL(string: "\(bundledScheme)://\(resource)")!,
            thumbnailUrl: nil,
            durationSeconds: 2,
            isLoopable: true,
            license: .bundled
        )
    }

    private static func bundleURL(for resourceName: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4", subdirectory: "DemoVideos")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }
}
