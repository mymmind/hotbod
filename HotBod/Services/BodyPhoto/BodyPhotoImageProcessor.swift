import UIKit

enum BodyPhotoImageProcessor {
    static func jpegData(from image: UIImage, compressionQuality: CGFloat = 0.85) -> Data? {
        normalizedImage(image).jpegData(compressionQuality: compressionQuality)
    }

    /// Redraws the image so EXIF orientation is baked into the pixel data.
    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }

    static func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: BodyPhotoPathResolver.resolve(path).path)
    }

    static func loadUIImage(at localImagePath: String) -> UIImage? {
        let url = BodyPhotoPathResolver.resolve(localImagePath)
        return UIImage(contentsOfFile: url.path)
    }
}

enum BodyPhotoImportError: Error {
    case invalidImage
    case missingUserProfile
}
