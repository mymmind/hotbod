import SwiftUI
import Charts
import PhotosUI

struct ProteinTrackerView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var entries: [ProteinEntry] = []
    @State private var weekEntries: [ProteinEntry] = []
    @State private var showCustom = false
    @State private var customGrams = ""
    @State private var customName = "Quick Add"
    @State private var foodSearchQuery = ""
    @State private var foodSearchResults: [FoodSearchResult] = []
    @State private var isSearchingFood = false

    private var goal: Double { environment.userProfile?.proteinGoalGrams ?? 145 }
    private var todayTotal: Double { entries.reduce(0) { $0 + $1.proteinGrams } }
    private var remaining: Double { max(0, goal - todayTotal) }

    private var proteinHeaderSubtitle: String {
        if remaining > 0 {
            return "\(Int(remaining))g left to hit today's \(Int(goal))g goal"
        }
        return "Goal hit — keep the streak alive."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForgeScreenHeader(
                        title: "Protein",
                        eyebrow: "Nutrition",
                        subtitle: proteinHeaderSubtitle,
                        accent: ForgeColors.accentBlue
                    )
                    proteinHero
                    VStack(spacing: 16) {
                        fastAddButtons
                        mealsList
                        weeklyChart
                    }
                    .padding()
                }
            }
            .background(ForgeColors.background)
            .forgeFloatingTabBarClearance()
            .forgeScreenNavigationHidden()
            .sheet(isPresented: $showCustom) { customEntrySheet }
            .task { await load() }
        }
    }

    private var proteinHero: some View {
        ForgeHeroCard(
            eyebrow: "Daily Intake",
            title: "\(Int(todayTotal)) / \(Int(goal))g",
            footerLine: "\(Int(remaining))g left",
            progress: goal > 0 ? todayTotal / goal : 0,
            accent: ForgeColors.accentBlue,
            titleStyle: .metric,
            titlePulseValue: todayTotal
        )
    }

    private var fastAddButtons: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Fast Add", accent: ForgeColors.accentBlue)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([10, 20, 25, 30], id: \.self) { grams in
                    Button("+\(grams)g") { Task { await addProtein(Double(grams), name: "+\(grams)g protein") } }
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(ForgeColors.accentBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(ForgeColors.accentBlue.opacity(0.35), lineWidth: 1))
                }
            }
            ForgeButton(title: "Custom", style: .secondary) { showCustom = true }
        }
    }

    private var mealsList: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Today")
            if entries.isEmpty {
                Text("No entries yet.").foregroundStyle(ForgeColors.muted)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.foodName).font(ForgeTypography.heading)
                            Text(entry.mealType.displayName).font(ForgeTypography.caption).foregroundStyle(ForgeColors.muted)
                        }
                        Spacer()
                        Text("\(Int(entry.proteinGrams))g")
                            .font(ForgeTypography.monoMetric)
                            .foregroundStyle(ForgeColors.accentBlue)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let id = entries[index].id
                            try? await environment.deleteProteinEntry(id: id)
                        }
                        await load()
                    }
                }
            }
        }
    }

    private var weeklyChart: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Weekly")
            Chart {
                ForEach(dailyTotals, id: \.day) { item in
                    BarMark(x: .value("Day", item.day), y: .value("g", item.grams))
                        .foregroundStyle(item.hitGoal ? ForgeColors.accentBlue : ForgeColors.muted.opacity(0.4))
                }
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(ForgeColors.accentBlue.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [4, 4]))
            }
            .frame(height: 160)
        }
    }

    private var dailyTotals: [(day: String, grams: Double, hitGoal: Bool)] {
        ProteinComplianceCalculator.dailyTotals(entries: weekEntries, days: 7, goalGrams: goal)
    }

    private var customEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ForgeTextField(label: "Search food", text: $foodSearchQuery)
                    .onChange(of: foodSearchQuery) { _, query in
                        Task { await searchFoods(query: query) }
                    }
                if isSearchingFood {
                    ProgressView()
                } else if !foodSearchResults.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(foodSearchResults) { result in
                                Button {
                                    customName = result.name
                                    if let protein = result.proteinPer100g {
                                        customGrams = String(format: "%.0f", protein)
                                    }
                                } label: {
                                    HStack {
                                        Text(result.name)
                                        Spacer()
                                        if let protein = result.proteinPer100g {
                                            Text("\(Int(protein))g/100g")
                                                .foregroundStyle(ForgeColors.muted)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
                ForgeTextField(label: "Food name", text: $customName)
                ForgeTextField(label: "Protein (g)", text: $customGrams)
                ForgeButton(title: "Save", style: .accent) {
                    if let g = Double(customGrams) {
                        Task {
                            await addProtein(g, name: customName, fromSearch: !foodSearchResults.isEmpty)
                            showCustom = false
                            foodSearchQuery = ""
                            foodSearchResults = []
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Custom Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showCustom = false
                        foodSearchQuery = ""
                        foodSearchResults = []
                    }
                }
            }
        }
    }

    private func searchFoods(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, environment.isFoodAPIConfigured else {
            foodSearchResults = []
            return
        }
        isSearchingFood = true
        defer { isSearchingFood = false }
        foodSearchResults = (try? await environment.searchFoods(query: trimmed)) ?? []
    }

    private func addProtein(_ grams: Double, name: String, fromSearch: Bool = false) async {
        let source: NutritionDataSource = fromSearch && environment.isFoodAPIConfigured ? .usda : .manual
        let entry = ProteinEntry(foodName: name, proteinGrams: grams, source: source)
        try? await environment.saveProteinEntry(entry)
        await load()
    }

    private func load() async {
        entries = await environment.fetchProteinEntries()
        weekEntries = await environment.fetchProteinEntries(lastDays: 7)
    }
}
