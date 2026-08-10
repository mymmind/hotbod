import Foundation

enum PhysiqueArchetypeCatalogLoader {
    static func load(
        bundle: Bundle = ExerciseCatalogLoader.resourceBundle
    ) -> [PhysiqueArchetypeCatalogEntry] {
        guard let url = bundle.url(forResource: "PhysiqueArchetypeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PhysiqueArchetypeCatalogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func indexedById(
        _ entries: [PhysiqueArchetypeCatalogEntry] = load()
    ) -> [String: PhysiqueArchetypeCatalogEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }
}
