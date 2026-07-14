import Foundation
import UIKit

/// Serializes body-photo imports so concurrent picks cannot read stale "previous" photos.
actor BodyPhotoImportCoordinator {
    static let shared = BodyPhotoImportCoordinator()

    func importPhoto(
        imageData: Data,
        userId: UUID,
        pose: BodyPhotoPoseType,
        weightKg: Double?,
        environment: AppEnvironment
    ) async throws -> BodyProgressPhoto {
        guard let uiImage = UIImage(data: imageData),
              let jpeg = BodyPhotoImageProcessor.jpegData(from: uiImage) else {
            throw BodyPhotoImportError.invalidImage
        }

        let dir = await environment.bodyPhotosDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        try jpeg.write(to: fileURL)

        do {
            let existing = await environment.fetchBodyPhotos(forUserId: userId)
            let previous = BodyProgressPhoto.latest(matching: pose, in: existing)

            var photo = BodyProgressPhoto(
                id: UUID(),
                userId: userId,
                date: Date(),
                poseType: pose,
                localImagePath: fileURL.path,
                weightKg: weightKg
            )
            photo.analysis = try? await environment.bodyPhotoAnalyzer.analyze(photo: photo, previous: previous)
            try await environment.saveBodyPhoto(photo, fileData: jpeg)
            return photo
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
    }
}
