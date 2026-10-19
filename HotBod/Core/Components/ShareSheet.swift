import SwiftUI

#if canImport(UIKit)
import LinkPresentation
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Supplies link metadata so the share sheet previews the workout card instead of the app icon.
final class WorkoutShareActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    let fileURL: URL

    init?(image: UIImage, title: String) {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotbod-workout-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        self.image = image
        self.title = title
        self.fileURL = url
        super.init()
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.url = fileURL
        metadata.originalURL = fileURL
        metadata.imageProvider = NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: image)
        return metadata
    }
}
#endif
