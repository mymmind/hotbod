import Foundation

extension AppEnvironment {
    func proteinSummary() async -> ProteinSummary {
        let goal = userProfile?.proteinGoalGrams ?? 145
        let start = Calendar.current.daysAgo(30)
        let entries = (try? await nutritionRepository.fetchEntries(from: start, to: Date())) ?? []
        return ProteinComplianceCalculator.summary(entries: entries, goalGrams: goal)
    }

    func fetchProteinEntries(for date: Date = Date()) async -> [ProteinEntry] {
        (try? await nutritionRepository.fetchEntries(for: date)) ?? []
    }

    func fetchProteinEntries(lastDays days: Int) async -> [ProteinEntry] {
        let start = Calendar.current.daysAgo(days)
        return (try? await nutritionRepository.fetchEntries(from: start, to: Date())) ?? []
    }

    func deleteProteinEntry(id: UUID) async throws {
        try await nutritionRepository.deleteEntry(id: id)
    }

    func saveProteinEntry(_ entry: ProteinEntry) async throws {
        try await nutritionRepository.saveEntry(entry)
        await cloudSyncIfSignedIn {
            try await cloudSyncService.pushProteinEntry(entry)
        }
    }

    func searchFoods(query: String) async throws -> [FoodSearchResult] {
        try await foodSearchService.searchFoods(query: query)
    }
}
