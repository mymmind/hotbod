import ImageIO
import SwiftUI
import UIKit

@MainActor
enum AnimatedGIFDecoder {
    struct Clip {
        let images: [UIImage]
        let duration: TimeInterval
    }

    static func clip(from data: Data) -> Clip? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var images: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            duration += frameDelay(source: source, index: index)
            images.append(UIImage(cgImage: image))
        }
        guard !images.isEmpty else { return nil }
        return Clip(images: images, duration: max(duration, 0.1))
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        let fallback = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return fallback }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? fallback
        return delay < 0.02 ? fallback : delay
    }
}

struct LoopingGIFView: UIViewRepresentable {
    let data: Data
    var animates: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityLabel = "A cat losing it"
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        let alreadyLooping = animates && uiView.isAnimating
        let alreadyStill = !animates && !uiView.isAnimating && uiView.image != nil
        guard !alreadyLooping, !alreadyStill else { return }
        apply(to: uiView)
    }

    private func apply(to view: UIImageView) {
        guard let clip = AnimatedGIFDecoder.clip(from: data) else { return }
        guard animates, clip.images.count > 1 else {
            view.stopAnimating()
            view.animationImages = nil
            view.image = clip.images.first
            return
        }
        view.animationImages = clip.images
        view.animationDuration = clip.duration
        view.animationRepeatCount = 0
        view.image = clip.images.first
        view.startAnimating()
    }
}
