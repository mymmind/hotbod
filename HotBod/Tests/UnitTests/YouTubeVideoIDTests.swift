import XCTest
@testable import HotBod

final class YouTubeVideoIDTests: XCTestCase {
    func testParsesWatchURL() throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=gMgvBspQ9lk&t=12s"))
        XCTAssertEqual(YouTubeVideoID(url: url)?.value, "gMgvBspQ9lk")
    }

    func testParsesShortShareURL() throws {
        let url = try XCTUnwrap(URL(string: "https://youtu.be/gMgvBspQ9lk"))
        XCTAssertEqual(YouTubeVideoID(url: url)?.value, "gMgvBspQ9lk")
    }

    func testParsesEmbedAndShortsURLs() throws {
        let embed = try XCTUnwrap(URL(string: "https://www.youtube.com/embed/gMgvBspQ9lk"))
        let shorts = try XCTUnwrap(URL(string: "https://www.youtube.com/shorts/gMgvBspQ9lk"))
        let mobile = try XCTUnwrap(URL(string: "https://m.youtube.com/watch?v=gMgvBspQ9lk"))
        XCTAssertEqual(YouTubeVideoID(url: embed)?.value, "gMgvBspQ9lk")
        XCTAssertEqual(YouTubeVideoID(url: shorts)?.value, "gMgvBspQ9lk")
        XCTAssertEqual(YouTubeVideoID(url: mobile)?.value, "gMgvBspQ9lk")
    }

    func testRejectsNonYouTubeAndShortIDs() throws {
        let otherHost = try XCTUnwrap(URL(string: "https://example.com/watch?v=gMgvBspQ9lk"))
        let shortID = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=short"))
        let file = try XCTUnwrap(URL(string: "file:///tmp/demo.mp4"))
        XCTAssertNil(YouTubeVideoID(url: otherHost))
        XCTAssertNil(YouTubeVideoID(url: shortID))
        XCTAssertNil(YouTubeVideoID(url: file))
    }

    func testEmbedRequestKeepsOfficialPlayerParameters() throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=gMgvBspQ9lk"))
        let videoID = try XCTUnwrap(YouTubeVideoID(url: url))
        let request = try XCTUnwrap(videoID.embedRequest(referer: "https://com.hotbod.app"))
        let requestURL = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://com.hotbod.app")
        XCTAssertEqual(components.host, "www.youtube.com")
        XCTAssertEqual(components.path, "/embed/gMgvBspQ9lk")
        XCTAssertEqual(items["playsinline"], "1")
        XCTAssertEqual(items["autoplay"], "1")
        XCTAssertEqual(items["mute"], "1")
        XCTAssertEqual(items["loop"], "1")
        XCTAssertEqual(items["playlist"], "gMgvBspQ9lk")
        XCTAssertEqual(items["controls"], "1")
    }
}

final class YouTubeExerciseCatalogTests: XCTestCase {
    func testBenchPressUsesYouTubeEmbed() throws {
        let video = try XCTUnwrap(YouTubeExerciseCatalog.video(for: "bench_press"))
        XCTAssertEqual(video.license, .youtube)
        XCTAssertEqual(YouTubeVideoID(url: video.url)?.value, "gMgvBspQ9lk")
    }

    func testEveryCatalogEntryMatchesASeedExercise() throws {
        let fileURL = try XCTUnwrap(
            ExerciseCatalogLoader.resourceBundle.url(forResource: "YouTubeExerciseVideos", withExtension: "json")
        )
        let raw = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: fileURL))
        let seedIDs = Set(ExerciseCatalogLoader.loadExercises().map(\.id))

        XCTAssertFalse(raw.isEmpty)
        for (exerciseID, urlString) in raw {
            XCTAssertTrue(seedIDs.contains(exerciseID), exerciseID)
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNotNil(YouTubeVideoID(url: url), urlString)
            XCTAssertEqual(YouTubeExerciseCatalog.video(for: exerciseID)?.url, url)
        }
    }

    func testUnknownExerciseHasNoYouTubeDemo() {
        XCTAssertNil(YouTubeExerciseCatalog.video(for: "not_an_exercise"))
    }
}
