import Foundation

struct FoodSearchResult: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var brand: String?
    var proteinPer100g: Double?
}

struct FoodNutritionDetails: Codable, Hashable {
    let id: String
    var name: String
    var proteinGrams: Double
    var calories: Double?
    var servingSize: String?
}
