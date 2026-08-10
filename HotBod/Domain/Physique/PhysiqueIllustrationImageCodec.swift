import UIKit

enum PhysiqueIllustrationImageCodec {
    static let maxEdge: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.8

    static func jpegDataForUpload(from image: UIImage) -> Data? {
        scaledImage(image, maxEdge: maxEdge).jpegData(compressionQuality: jpegQuality)
    }

    static func jpegDataForUpload(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegDataForUpload(from: image)
    }

    private static func scaledImage(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let normalized = normalizedImage(image)
        let size = normalized.size
        let maxDimension = max(size.width, size.height)
        guard maxDimension > maxEdge else { return normalized }

        let scale = maxEdge / maxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }
}
