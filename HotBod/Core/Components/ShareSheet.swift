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

/// Shares the workout card as an image.
/// A file URL or `iconProvider` collapses the system preview to app-icon size, so the
/// item is the image itself and link metadata only supplies the title plus that image.
final class WorkoutShareActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    private let provider: NSItemProvider

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        let provider = NSItemProvider(object: image)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.suggestedName = trimmed.isEmpty ? "HotBod Workout" : trimmed
        self.provider = provider
        super.init()
    }

    func cleanup() {}

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        provider
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        provider
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = provider
        return metadata
    }
}
#endif
