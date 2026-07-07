import Foundation

extension AppEnvironment {
    func fetchBodyPhotos() async -> [BodyProgressPhoto] {
        (try? await bodyProgressRepository.fetchPhotos()) ?? []
    }

    func deleteBodyPhoto(id: UUID) async throws {
        try await bodyProgressRepository.deletePhoto(id: id)
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
    }
}
