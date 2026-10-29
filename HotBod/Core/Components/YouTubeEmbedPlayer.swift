import SwiftUI
import WebKit

/// Official YouTube embed. Playback stays inside YouTube's player; the app does not fetch the media file.
struct YouTubeEmbedPlayer: UIViewRepresentable {
    let videoID: YouTubeVideoID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        load(videoID, into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedID != videoID.value else { return }
        load(videoID, into: webView, coordinator: context.coordinator)
    }

    private func load(_ videoID: YouTubeVideoID, into webView: WKWebView, coordinator: Coordinator) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.hotbod.app"
        guard let request = videoID.embedRequest(referer: "https://\(bundleID)") else { return }
        coordinator.loadedID = videoID.value
        webView.load(request)
    }

    final class Coordinator {
        var loadedID: String?
    }
}
