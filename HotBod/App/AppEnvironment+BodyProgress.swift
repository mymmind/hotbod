import Foundation
import UIKit

extension AppEnvironment {
    func fetchBodyPhotos(forUserId userId: UUID? = nil) async -> [BodyProgressPhoto] {
        let all = (try? await bodyProgressRepository.fetchPhotos()) ?? []
        let filterId = userId ?? userProfile?.id
        guard let filterId else { return [] }
        return all.filter { $0.userId == filterId }
    }

    func bodyPhotosDirectory() -> URL {
        if let local = bodyProgressRepository as? LocalBodyProgressRepository {
            return local.photosDirectory
        }
        return PersistenceHelper.appSupportURL.appendingPathComponent("photos", isDirectory: true)
    }

    func saveBodyPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws {
        try await bodyProgressRepository.savePhoto(photo)
        if isSignedIn, photoCloudBackupEnabled {
            try? await cloudSyncService.pushPhoto(photo, fileData: fileData)
        }
        bumpBodyPhotoRevision()
    }

    @discardableResult
    func importBodyPhoto(
        imageData: Data,
        userId: UUID,
        pose: BodyPhotoPoseType,
        weightKg: Double?
    ) async throws -> BodyProgressPhoto {
        try await BodyPhotoImportCoordinator.shared.importPhoto(
            imageData: imageData,
            userId: userId,
            pose: pose,
            weightKg: weightKg,
            environment: self
        )
    }

    func realignBodyPhotoUserIds(from oldId: UUID, to newId: UUID) async {
        guard oldId != newId else { return }
        let all = (try? await bodyProgressRepository.fetchPhotos()) ?? []
        var changed = false
        for photo in all where photo.userId == oldId {
            let realigned = BodyProgressPhoto(
                id: photo.id,
                userId: newId,
                date: photo.date,
                poseType: photo.poseType,
                localImagePath: photo.localImagePath,
                remoteImageUrl: photo.remoteImageUrl,
                weightKg: photo.weightKg,
                notes: photo.notes,
                analysis: photo.analysis
            )
            try? await bodyProgressRepository.savePhoto(realigned)
            changed = true
        }
        if changed { bumpBodyPhotoRevision() }
    }

    var isPhotoTrackingEnabled: Bool {
        userProfile?.photoTrackingEnabled == true
    }

    func bumpBodyPhotoRevision() {
        bodyPhotoRevision += 1
    }
}
