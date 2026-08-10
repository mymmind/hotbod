import Foundation

actor LocalPhysiqueIllustrationStore {
    private let directoryName: String
    private static let indexFilename = "index.json"

    init(directoryName: String = "physique_illustrations") {
        self.directoryName = directoryName
    }

    private var illustrationsDirectory: URL {
        PersistenceHelper.appSupportURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: illustrationsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func imageFilename(for assessmentId: UUID) -> String {
        "\(assessmentId.uuidString).jpg"
    }

    private func loadIndex() -> [String: PhysiqueIllustrationRecord] {
        let url = illustrationsDirectory.appendingPathComponent(Self.indexFilename)
        guard let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode([String: PhysiqueIllustrationRecord].self, from: data) else {
            return [:]
        }
        return index
    }

    private func saveIndex(_ index: [String: PhysiqueIllustrationRecord]) throws {
        try ensureDirectory()
        let url = illustrationsDirectory.appendingPathComponent(Self.indexFilename)
        let data = try JSONEncoder().encode(index)
        try data.write(to: url, options: .atomic)
    }

    func fetch(assessmentId: UUID) throws -> (PhysiqueIllustrationRecord, Data)? {
        let index = loadIndex()
        guard let record = index[assessmentId.uuidString] else { return nil }
        let imageURL = illustrationsDirectory.appendingPathComponent(record.localImagePath)
        guard let data = try? Data(contentsOf: imageURL), !data.isEmpty else { return nil }
        return (record, data)
    }

    func save(
        assessmentId: UUID,
        sourcePhotoId: UUID,
        imageData: Data
    ) throws -> PhysiqueIllustrationRecord {
        try ensureDirectory()
        let filename = imageFilename(for: assessmentId)
        let imageURL = illustrationsDirectory.appendingPathComponent(filename)
        try imageData.write(to: imageURL, options: .atomic)

        let record = PhysiqueIllustrationRecord(
            assessmentId: assessmentId,
            sourcePhotoId: sourcePhotoId,
            createdAt: Date(),
            localImagePath: filename
        )
        var index = loadIndex()
        index[assessmentId.uuidString] = record
        try saveIndex(index)
        return record
    }

    func clear(assessmentId: UUID) throws {
        var index = loadIndex()
        guard let record = index.removeValue(forKey: assessmentId.uuidString) else { return }
        let imageURL = illustrationsDirectory.appendingPathComponent(record.localImagePath)
        try? FileManager.default.removeItem(at: imageURL)
        try saveIndex(index)
    }

    func clearAll() throws {
        let directory = illustrationsDirectory
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }
}
