import Foundation

final class USDAFoodSearchService: FoodSearchService, Sendable {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchFoods(query: String) async throws -> [FoodSearchResult] {
        guard FoodAPIConfig.isConfigured, let apiKey = FoodAPIConfig.apiKey else {
            throw FoodSearchError.notConfigured
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        guard var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search") else {
            throw FoodSearchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy,Survey (FNDDS),Branded")
        ]
        guard let url = components.url else { throw FoodSearchError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        try validateHTTP(response)
        let payload = try decoder.decode(USDASearchResponse.self, from: data)

        return payload.foods.map { food in
            FoodSearchResult(
                id: "fdc_\(food.fdcId)",
                name: food.description,
                brand: food.brandOwner,
                proteinPer100g: proteinPer100g(from: food.foodNutrients)
            )
        }
    }

    func getFoodDetails(id: String) async throws -> FoodNutritionDetails {
        guard FoodAPIConfig.isConfigured, let apiKey = FoodAPIConfig.apiKey else {
            throw FoodSearchError.notConfigured
        }
        let fdcId = id.hasPrefix("fdc_") ? String(id.dropFirst(4)) : id
        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/food/\(fdcId)?api_key=\(apiKey)") else {
            throw FoodSearchError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        try validateHTTP(response)
        let food = try decoder.decode(USDAFoodDetail.self, from: data)

        let protein = proteinPer100g(from: food.foodNutrients) ?? 0
        let calories = nutrientValue(named: "Energy", in: food.foodNutrients)
            ?? nutrientValue(id: 1008, in: food.foodNutrients)

        return FoodNutritionDetails(
            id: "fdc_\(food.fdcId)",
            name: food.description,
            proteinGrams: protein,
            calories: calories,
            servingSize: food.servingSize.flatMap { size in
                size.value.map { "\(Int($0)) \(size.unit ?? "g")" }
            } ?? "100g"
        )
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FoodSearchError.requestFailed
        }
    }

    private func proteinPer100g(from nutrients: [USDANutrient]?) -> Double? {
        nutrientValue(id: 1003, in: nutrients)
            ?? nutrientValue(named: "Protein", in: nutrients)
    }

    private func nutrientValue(id: Int, in nutrients: [USDANutrient]?) -> Double? {
        nutrients?.first { $0.nutrientId == id || $0.nutrient?.id == id }?.value
    }

    private func nutrientValue(named name: String, in nutrients: [USDANutrient]?) -> Double? {
        nutrients?.first {
            $0.nutrientName?.caseInsensitiveCompare(name) == .orderedSame
                || $0.nutrient?.name?.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}

enum FoodSearchError: LocalizedError {
    case notConfigured
    case invalidResponse
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Food API is not configured."
        case .invalidResponse: "Invalid food API response."
        case .requestFailed: "Food search request failed."
        }
    }
}

private struct USDASearchResponse: Decodable {
    let foods: [USDAFoodSummary]
}

private struct USDAFoodSummary: Decodable {
    let fdcId: Int
    let description: String
    let brandOwner: String?
    let foodNutrients: [USDANutrient]?
}

private struct USDAFoodDetail: Decodable {
    let fdcId: Int
    let description: String
    let servingSize: USDAServingSize?
    let foodNutrients: [USDANutrient]?
}

private struct USDAServingSize: Decodable {
    let value: Double?
    let unit: String?
}

private struct USDANutrient: Decodable {
    let nutrientId: Int?
    let nutrientName: String?
    let value: Double?
    let nutrient: USDANutrientInfo?
}

private struct USDANutrientInfo: Decodable {
    let id: Int?
    let name: String?
}
