import SwiftUI
import Charts
import Observation

struct ProgressDashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = ProgressDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForgeScreenHeader(
                        title: "Progress",
                        eyebrow: "Analytics",
                        subtitle: progressHeaderSubtitle
                    )
                    VStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            VStack(spacing: 16) {
                                complianceCard
                                e1rmTrendCard
                                volumeTrendCard
                                topLiftsCard
                                strengthScoreCard
                                recoveryCard
                                insightsCard
                                bodyProgressCard
                            }
                            .forgeAnimatedContent(id: "loaded")
                        }
                    }
                    .padding()
                    .animation(ForgeMotion.standard, value: viewModel.isLoading)
                }
            }
            .background(ForgeColors.background)
            .forgeFloatingTabBarClearance()
            .forgeScreenNavigationHidden()
            .accessibilityIdentifier("progress.dashboard")
            .task(id: environment.bodyPhotoRevision) {
                await viewModel.loadData(from: environment)
            }
            .onChange(of: environment.todayWorkout) { _, _ in
                Task {
                    await viewModel.loadData(from: environment)
                }
            }
        }
    }

    private var progressHeaderSubtitle: String {
        if viewModel.isLoading {
            return "Loading your trends..."
        }
        return "\(viewModel.workoutFrequency) sessions this week · \(Int(viewModel.proteinCompliancePercent))% protein compliance"
    }

    private var complianceCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Compliance", subtitle: "Weekly performance", accent: ForgeColors.accent)
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protein").font(ForgeTypography.caption).foregroundStyle(ForgeColors.accentBlue)
                    HStack(alignment: .center, spacing: 4) {
                        Text("\(Int(viewModel.proteinCompliancePercent))%")
                            .font(ForgeTypography.title)
                            .foregroundStyle(ForgeColors.accentBlue)
                        ProgressView(value: viewModel.proteinCompliancePercent / 100)
                            .tint(ForgeColors.accentBlue)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts").font(ForgeTypography.caption).foregroundStyle(ForgeColors.accent)
                    HStack(alignment: .center, spacing: 4) {
                        Text("\(viewModel.workoutFrequency)/\(viewModel.trainingDaysPerWeek)")
                            .font(ForgeTypography.title)
                            .foregroundStyle(ForgeColors.accent)
                        ProgressView(value: Double(viewModel.workoutFrequency) / Double(max(1, viewModel.trainingDaysPerWeek)))
                            .tint(ForgeColors.accent)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("progress.compliance")
    }

    // MARK: - E1RM Trend Card

    private var e1rmTrendCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "E1RM Trend", subtitle: "Last 12 weeks · \(viewModel.selectedLiftForChart.name)", accent: ForgeColors.accent)
            if !viewModel.e1rmChartData.isEmpty {
                Chart(viewModel.e1rmChartData) { point in
                    LineMark(x: .value("Week", point.weekLabel), y: .value("E1RM", point.e1rm))
                        .foregroundStyle(ForgeColors.accent)
                    PointMark(x: .value("Week", point.weekLabel), y: .value("E1RM", point.e1rm))
                        .foregroundStyle(ForgeColors.accent)
                }
                .chartXAxis(.hidden)
                .frame(height: 160)
                .padding(.vertical, 8)
                Text("Peak: \(String(format: "%.1f", viewModel.e1rmPeakValue)) kg")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            } else {
                Text("No strength data yet. Complete some workouts.")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Volume Trend Card

    private var volumeTrendCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Volume Trend", subtitle: "Weekly sets & reps", accent: ForgeColors.accent)
            if !viewModel.volumeChartData.isEmpty {
                Chart(viewModel.volumeChartData) { point in
                    BarMark(x: .value("Week", point.weekLabel), y: .value("Sets", point.totalSets))
                        .foregroundStyle(ForgeColors.accent.opacity(0.85))
                }
                .chartXAxis(.hidden)
                .frame(height: 140)
                .padding(.vertical, 8)
                HStack {
                    Text("Avg Sets/Week")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                    Spacer()
                    Text(String(format: "%.0f", viewModel.avgSetsPerWeek))
                        .font(ForgeTypography.monoMetric)
                }
            } else {
                Text("No volume data yet. Complete some workouts.")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Top Lifts Card

    private var topLiftsCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Top Lifts", subtitle: "Estimated 1RM")
            if !viewModel.topLifts.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.topLifts.prefix(5), id: \.exercise.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exercise.name).font(ForgeTypography.body)
                                Text(item.exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                                    .font(ForgeTypography.caption)
                                    .foregroundStyle(ForgeColors.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f kg", item.e1rm))
                                    .font(ForgeTypography.monoMetric)
                                if let changePercent = item.changePercent {
                                    Text("\(changePercent > 0 ? "+" : "")\(String(format: "%.1f", changePercent))%")
                                        .font(ForgeTypography.caption)
                                        .foregroundStyle(changePercent > 0 ? ForgeColors.accentGreen : ForgeColors.accent)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("No lift data yet. Start logging workouts.")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Strength Score Card

    private var strengthScoreCard: some View {
        ForgeCard {
            ForgeSectionHeader(
                title: "Strength Score",
                subtitle: "Per muscle group · 0–100",
                accent: ForgeColors.accent
            )
            if !viewModel.muscleStrengthScores.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.muscleStrengthScores.prefix(6)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.muscleGroup.displayName)
                                    .font(ForgeTypography.body)
                                    .lineLimit(1)
                                Text(item.anchorExerciseName)
                                    .font(ForgeTypography.caption)
                                    .foregroundStyle(ForgeColors.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView(value: Double(item.score) / 100)
                                    .tint(ForgeColors.accent)
                                    .frame(maxWidth: 80, alignment: .leading)
                                Text("\(item.score)")
                                    .font(ForgeTypography.monoMetric)
                                    .foregroundStyle(ForgeColors.accent)
                                    .frame(width: 28, alignment: .trailing)
                            }
                        }
                    }
                }
            } else {
                Text("Log weighted sets and add body weight in Settings to see strength scores.")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Recovery Card

    private var recoveryCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Recovery", subtitle: "Muscle group readiness", accent: ForgeColors.accentGreen)
            if !viewModel.recoveryByMuscle.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.recoveryByMuscle.prefix(6), id: \.muscleGroup) { state in
                        HStack {
                            Text(state.muscleGroup.displayName)
                                .font(ForgeTypography.body)
                                .lineLimit(1)
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView(value: state.recoveryPercentage / 100)
                                    .tint(ForgeColors.readiness(state.recoveryPercentage))
                                    .frame(maxWidth: 80, alignment: .leading)
                                Text("\(Int(state.recoveryPercentage))%")
                                    .font(ForgeTypography.monoMetric)
                                    .foregroundStyle(ForgeColors.readiness(state.recoveryPercentage))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            } else {
                Text("Recovery data loading...")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Insights Card

    private var insightsCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Insights", subtitle: "Last 7 days")
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.insights.prefix(4), id: \.self) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                                .font(ForgeTypography.body)
                                .foregroundStyle(ForgeColors.accent)
                            Text(insight)
                                .font(ForgeTypography.body)
                                .lineLimit(2)
                        }
                    }
                }
            } else {
                Text("Complete workouts and log protein to see insights.")
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Body Progress Card

    private var bodyProgressCard: some View {
        NavigationLink {
            BodyProgressView()
        } label: {
            ForgeCard {
                ForgeSectionHeader(title: "Body Progress", subtitle: "Photo timeline")
                if !viewModel.bodyPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BodyProgressPhoto.sortedByDateDescending(viewModel.bodyPhotos).prefix(6), id: \.id) { photo in
                                VStack(alignment: .center, spacing: 8) {
                                    if let image = loadImage(path: photo.localImagePath) {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 100)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(ForgeColors.muted.opacity(0.3))
                                            .frame(width: 80, height: 100)
                                    }
                                    Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(ForgeTypography.caption)
                                        .foregroundStyle(ForgeColors.muted)
                                        .lineLimit(1)
                                }
                                .transition(ForgeMotion.appear)
                            }
                        }
                    }
                } else {
                    Text(bodyProgressEmptyMessage)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("progress.bodyProgressLink")
    }

    private var bodyProgressEmptyMessage: String {
        if environment.isPhotoTrackingEnabled {
            return "Photo tracking is on. Tap to add your first progress photo."
        }
        return "No progress photos yet. Tap to add your first photo."
    }

    private func loadImage(path: String) -> Image? {
        guard BodyPhotoImageProcessor.fileExists(at: path),
              let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class ProgressDashboardViewModel {
    var isLoading = false
    var proteinCompliancePercent: Double = 0
    var workoutFrequency: Int = 0
    var trainingDaysPerWeek: Int = 4
    var e1rmChartData: [E1RMChartPoint] = []
    var e1rmPeakValue: Double = 0
    var volumeChartData: [VolumeChartPoint] = []
    var avgSetsPerWeek: Double = 0
    var topLifts: [(exercise: Exercise, e1rm: Double, changePercent: Double?)] = []
    var muscleStrengthScores: [StrengthHistory.MuscleStrengthScore] = []
    var recoveryByMuscle: [MuscleRecoveryState] = []
    var bodyPhotos: [BodyProgressPhoto] = []
    var insights: [String] = []
    var selectedLiftForChart: Exercise = Exercise.mock(name: "Top Lift")

    func loadData(from environment: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }

        async let statsTask = environment.fetchExerciseStats()
        async let summariesTask = environment.fetchSessionSummaries()
        async let proteinTask = environment.fetchProteinEntries(lastDays: 7)
        async let photosTask = environment.fetchBodyPhotos()
        async let allExercisesTask = environment.fetchAllExercises()

        let stats = await statsTask
        let summaries = await summariesTask
        let proteinEntries = await proteinTask
        let photos = await photosTask
        let exercises = await allExercisesTask

        bodyPhotos = photos
        recoveryByMuscle = environment.recoveryStates
        trainingDaysPerWeek = environment.userProfile?.trainingDaysPerWeek ?? 4

        // Calculate protein compliance
        let proteinGoal = environment.userProfile?.proteinGoalGrams ?? 150
        proteinCompliancePercent = ProteinComplianceCalculator.weeklyCompliancePercent(
            entries: proteinEntries,
            goalGrams: proteinGoal
        )

        // Calculate workout frequency (this week)
        let weekStart = Calendar.current.daysAgo(7)
        let thisWeekWorkouts = summaries.filter { $0.completedAt > weekStart }
        workoutFrequency = thisWeekWorkouts.count

        // Process E1RM trend
        if let topLift = StrengthHistory.topLifts(stats: stats, exercises: exercises).first {
            selectedLiftForChart = topLift.exercise
            let trendPoints = StrengthHistory.e1rmTrend(for: topLift.exercise.id, stats: stats)
            e1rmChartData = buildE1RMChartData(from: trendPoints)
            e1rmPeakValue = trendPoints.map(\.e1rm).max() ?? 0
        }

        // Process volume trend
        volumeChartData = buildVolumeChartData(from: summaries)
        avgSetsPerWeek = volumeChartData.map(\.totalSets).average()

        // Process top lifts
        topLifts = StrengthHistory.topLifts(stats: stats, exercises: exercises).map { exercise, e1rm in
            let previousAverage = stats.first(where: { $0.exerciseId == exercise.id })?
                .recentSets.dropLast().map { $0.weightKg ?? 0 }.average() ?? 0
            let changePercent = previousAverage > 0 ? ((e1rm - previousAverage) / previousAverage) * 100 : nil
            return (exercise: exercise, e1rm: e1rm, changePercent: changePercent)
        }

        let bodyweightKg = environment.userProfile?.weightKg ?? 0
        muscleStrengthScores = StrengthHistory.muscleGroupScores(
            stats: stats,
            exercises: exercises,
            bodyweightKg: bodyweightKg
        )

        // Generate insights
        generateInsights(
            stats: stats,
            summaries: summaries,
            proteinEntries: proteinEntries,
            exercises: exercises,
            proteinGoalGrams: proteinGoal
        )
    }

    private func buildE1RMChartData(from points: [StrengthHistory.DataPoint]) -> [E1RMChartPoint] {
        let sortedPoints = points.sorted { $0.date < $1.date }.suffix(12)
        let calendar = Calendar.current
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMM d"

        return sortedPoints.map { point in
            E1RMChartPoint(
                date: point.date,
                weekLabel: weekFormatter.string(from: point.date),
                e1rm: point.e1rm
            )
        }
    }

    private func buildVolumeChartData(from summaries: [WorkoutSessionSummary]) -> [VolumeChartPoint] {
        let calendar = Calendar.current
        var weeklyData: [Date: Int] = [:]

        for summary in summaries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: summary.completedAt)?.start ?? summary.completedAt
            weeklyData[weekStart, default: 0] += summary.totalSets
        }

        let sortedWeeks = weeklyData.keys.sorted().suffix(12)
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMM d"

        return sortedWeeks.map { date in
            VolumeChartPoint(
                date: date,
                weekLabel: weekFormatter.string(from: date),
                totalSets: weeklyData[date] ?? 0
            )
        }
    }

    private func generateInsights(
        stats: [UserExerciseStats],
        summaries: [WorkoutSessionSummary],
        proteinEntries: [ProteinEntry],
        exercises: [Exercise],
        proteinGoalGrams: Double
    ) {
        var generatedInsights: [String] = []

        // Strength insight
        if let topLift = stats.sorted(by: { ($0.estimatedOneRepMax ?? 0) > ($1.estimatedOneRepMax ?? 0) }).first,
           let exercise = exercises.first(where: { $0.id == topLift.exerciseId }),
           let e1rm = topLift.estimatedOneRepMax,
           let lastWeight = topLift.lastWeightKg {
            let gain = e1rm - lastWeight
            if gain > 0 {
                generatedInsights.append("\(exercise.name) E1RM at \(String(format: "%.1f", e1rm)) kg (+\(String(format: "%.1f", gain)) kg)")
            }
        }

        // Volume insight
        let weekStart = Calendar.current.daysAgo(7)
        let thisWeekVolume = summaries.filter { $0.completedAt > weekStart }.reduce(0) { $0 + $1.totalSets }
        if thisWeekVolume > 0 {
            generatedInsights.append("\(thisWeekVolume) sets completed this week")
        }

        // Protein insight
        let proteinPercent = ProteinComplianceCalculator.weeklyCompliancePercent(
            entries: proteinEntries,
            goalGrams: proteinGoalGrams
        )
        if proteinPercent > 80 {
            generatedInsights.append("Protein adherence at \(Int(proteinPercent))%")
        }

        // Workout frequency insight
        let workoutCount = summaries.filter { $0.completedAt > weekStart }.count
        if workoutCount >= 4 {
            generatedInsights.append("\(workoutCount) workouts logged this week")
        }

        // Recovery insight
        let avgRecovery = recoveryByMuscle.map(\.recoveryPercentage).average()
        if avgRecovery < 60 {
            generatedInsights.append("Average recovery at \(Int(avgRecovery))% — consider a deload week")
        } else if avgRecovery > 85 {
            generatedInsights.append("Muscles well-recovered — ready for heavy session")
        }

        insights = generatedInsights
    }
}

// MARK: - Chart Models

struct E1RMChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weekLabel: String
    let e1rm: Double
}

struct VolumeChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weekLabel: String
    let totalSets: Int
}

// MARK: - Helper Extensions

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

extension Array where Element == Int {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}

extension Exercise {
    static func mock(name: String) -> Exercise {
        Exercise(
            id: "mock",
            name: name,
            slug: "mock",
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            equipment: [.barbell],
            movementPattern: .horizontalPush,
            difficulty: .intermediate,
            forceType: nil,
            mechanics: .compound,
            instructions: [],
            formCues: [],
            commonMistakes: [],
            contraindications: [],
            substitutions: [],
            progressions: [],
            regressions: [],
            demoVideos: [],
            imageUrl: nil,
            tags: []
        )
    }
}

// MARK: - Preview

#Preview {
    ProgressDashboardView()
        .environment(AppEnvironment())
        .environment(AppRouter())
}
