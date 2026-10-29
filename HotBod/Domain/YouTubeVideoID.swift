import Foundation

/// An 11-character YouTube video id parsed from a watch, share, embed, or shorts URL.
struct YouTubeVideoID: Hashable, Sendable {
    let value: String

    init?(url: URL) {
        guard let value = Self.videoID(from: url) else { return nil }
        self.value = value
    }

    /// Embed playback request. YouTube rejects a `WKWebView` load that has no Referer (error 153).
    func embedRequest(referer: String) -> URLRequest? {
        guard var components = URLComponents(string: "https://www.youtube.com/embed/\(value)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "mute", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "loop", value: "1"),
            URLQueryItem(name: "playlist", value: value),
            URLQueryItem(name: "controls", value: "1")
        ]
        guard let embedURL = components.url else { return nil }
        var request = URLRequest(url: embedURL)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("strict-origin-when-cross-origin", forHTTPHeaderField: "Referrer-Policy")
        return request
    }

    private static func videoID(from url: URL) -> String? {
        guard let host = url.host, isYouTubeHost(host) else { return nil }
        if isShortLinkHost(host) {
            return validated(pathComponents(of: url).first)
        }
        return videoIDFromYouTubePath(url)
    }

    private static func videoIDFromYouTubePath(_ url: URL) -> String? {
        let parts = pathComponents(of: url)
        if parts.first == "watch" || parts.isEmpty {
            return validated(queryValue(named: "v", in: url))
        }
        let embeddedRoots = ["embed", "shorts", "live", "v"]
        if let root = parts.first, embeddedRoots.contains(root), parts.count >= 2 {
            return validated(parts[1])
        }
        return nil
    }

    private static func isYouTubeHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "youtu.be" || host.hasSuffix(".youtu.be") { return true }
        if host == "youtube.com" || host.hasSuffix(".youtube.com") { return true }
        if host == "youtube-nocookie.com" || host.hasSuffix(".youtube-nocookie.com") { return true }
        return false
    }

    private static func isShortLinkHost(_ host: String) -> Bool {
        let host = host.lowercased()
        return host == "youtu.be" || host.hasSuffix(".youtu.be")
    }

    private static func pathComponents(of url: URL) -> [String] {
        url.pathComponents.filter { $0 != "/" }
    }

    private static func queryValue(named name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

    private static func validated(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 11 else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        guard trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return trimmed
    }
}
