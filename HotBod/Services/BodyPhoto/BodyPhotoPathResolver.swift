import Foundation

/// Resolves body-photo image paths stored as filenames under Application Support/photos.
enum BodyPhotoPathResolver {
    static var photosDirectory: URL {
        PersistenceHelper.appSupportURL.appendingPathComponent("photos", isDirectory: true)
    }

    /// Absolute file URL for reading/deleting. Accepts relative filenames or legacy absolute paths.
    static func resolve(_ localImagePath: String) -> URL {
        if localImagePath.hasPrefix("/") {
            let absolute = URL(fileURLWithPath: localImagePath)
            if FileManager.default.fileExists(atPath: absolute.path) {
                return absolute
            }
            let relocated = photosDirectory.appendingPathComponent(absolute.lastPathComponent)
            if FileManager.default.fileExists(atPath: relocated.path) {
                return relocated
            }
            return absolute
        }
        return photosDirectory.appendingPathComponent(localImagePath)
    }

    /// Canonical storage form: filename only under `photos/`.
    static func storagePath(for fileURL: URL) -> String {
        fileURL.lastPathComponent
    }

    /// Returns an updated photo when a legacy absolute path can be rewritten to a relative filename.
    static func migratedPhoto(from photo: BodyProgressPhoto) -> BodyProgressPhoto? {
        let resolved = resolve(photo.localImagePath)
        let relative = storagePath(for: resolved)
        guard photo.localImagePath != relative else { return nil }
        guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        var updated = photo
        updated.localImagePath = relative
        return updated
    }
}
