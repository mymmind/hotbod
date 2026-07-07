import Foundation

enum ExerciseCatalogLoader {
    static func loadExercises() -> [Exercise] {
        let seed = ExerciseSeedLoader.loadSeed()
        let content = loadContentBundle()
        return seed.map { merge($0, content: content.exercises[$0.id], groups: content.substitutionGroups) }
    }

    static func loadSubstitutionGroups() -> [ExerciseSubstitutionGroup] {
        loadContentBundle().substitutionGroups
    }

    static func loadAliasIndex() -> [String: String] {
        let content = loadContentBundle()
        var index: [String: String] = [:]
        for (exerciseId, entry) in content.exercises {
            for alias in entry.aliases ?? [] {
                index[ExerciseIdResolver.normalize(alias)] = exerciseId
            }
        }
        return index
    }

    static func buildGroupIndex(exercises: [Exercise]) -> [String: [Exercise]] {
        Dictionary(grouping: exercises) { ExerciseCatalog.resolvedGroupId(for: $0) }
    }

    // MARK: - Private

    private static func loadContentBundle() -> ExerciseContentBundle {
        guard let url = Bundle.main.url(forResource: "ExerciseContent", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(ExerciseContentBundle.self, from: data) else {
            return ExerciseContentBundle()
        }
        return bundle
    }

    private static func merge(
        _ exercise: Exercise,
        content: ExerciseContentEntry?,
        groups: [ExerciseSubstitutionGroup]
    ) -> Exercise {
        var merged = exercise
        if let content {
            if let aliases = content.aliases { merged.aliases = aliases }
            if let instructions = content.instructions { merged.instructions = instructions }
            if let formCues = content.formCues { merged.formCues = formCues }
            if let commonMistakes = content.commonMistakes { merged.commonMistakes = commonMistakes }
            if let groupId = content.substitutionGroupId { merged.substitutionGroupId = groupId }
            if let substitutions = content.substitutions { merged.substitutions = substitutions }
            if let description = content.description, !description.isEmpty, merged.instructions.isEmpty {
                merged.instructions = [description]
            }
        }
        if merged.substitutionGroupId == nil {
            merged.substitutionGroupId = ExerciseCatalog.autoGroupId(for: merged)
        }
        if let groupId = merged.substitutionGroupId,
           groups.contains(where: { $0.id == groupId }) == false {
            // Group id from content with no metadata — still valid for swapping.
        }
        return merged
    }
}
