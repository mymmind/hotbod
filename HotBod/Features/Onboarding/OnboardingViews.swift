import SwiftUI
import UIKit

import SwiftUI
import UIKit
import Observation

struct OnboardingContainerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.progress)
                .tint(ForgeColors.accent)
                .padding(.horizontal)
                .padding(.top, 8)

            TabView(selection: $viewModel.step) {
                OnboardingWelcomeView(viewModel: viewModel).tag(0).forgeAnimatedContent(id: 0)
                OnboardingGoalView(viewModel: viewModel).tag(1).forgeAnimatedContent(id: 1)
                OnboardingExperienceView(viewModel: viewModel).tag(2).forgeAnimatedContent(id: 2)
                OnboardingLocationView(viewModel: viewModel).tag(3).forgeAnimatedContent(id: 3)
                OnboardingEquipmentView(viewModel: viewModel).tag(4).forgeAnimatedContent(id: 4)
                OnboardingScheduleView(viewModel: viewModel).tag(5).forgeAnimatedContent(id: 5)
                OnboardingBodyStatsView(viewModel: viewModel).tag(6).forgeAnimatedContent(id: 6)
                OnboardingLimitationsView(viewModel: viewModel).tag(7).forgeAnimatedContent(id: 7)
                OnboardingProteinView(viewModel: viewModel).tag(8).forgeAnimatedContent(id: 8)
                OnboardingPhotoView(viewModel: viewModel).tag(9).forgeAnimatedContent(id: 9)
                OnboardingPlanView(viewModel: viewModel).tag(10).forgeAnimatedContent(id: 10)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(ForgeMotion.standard, value: viewModel.step)

            HStack(spacing: 12) {
                if viewModel.step > 0 {
                    ForgeButton(title: "Back", style: .secondary) { viewModel.back() }
                }
                ForgeButton(title: viewModel.step == 10 ? "Start Today's Workout" : "Continue", style: .accent) {
                    if viewModel.step == 10 {
                        Task { await completeOnboarding() }
                    } else {
                        viewModel.next()
                    }
                }
            }
            .padding()
        }
        .background(ForgeColors.background)
        .onChange(of: viewModel.step) { _, _ in
            dismissKeyboard()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func completeOnboarding() async {
        viewModel.profile.updatedAt = Date()
        try? await environment.completeOnboarding(profile: viewModel.profile)
        await environment.regenerateTodayWorkout(profile: viewModel.profile)
        router.showMain()
    }
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step = 0
    var profile = UserProfile.empty()

    var progress: Double { Double(step + 1) / 11.0 }

    func next() {
        withAnimation(ForgeMotion.standard) { step = min(step + 1, 10) }
    }

    func back() {
        withAnimation(ForgeMotion.standard) { step = max(step - 1, 0) }
    }
}

struct OnboardingWelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Rectangle()
                .fill(ForgeColors.accent)
                .frame(width: 48, height: 4)
            Text("TRAINING THAT ADAPTS.")
                .font(ForgeTypography.largeTitle)
                .foregroundStyle(ForgeColors.foreground)
            Text("Dynamic strength workouts, protein tracking, visual progress, and an AI coach that explains the plan.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingExperienceView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Experience", subtitle: "How do you train?")
                ForEach(ExperienceLevel.allCases) { level in
                    SelectableRow(
                        title: level.displayName,
                        subtitle: level.description,
                        isSelected: viewModel.profile.experienceLevel == level
                    ) { viewModel.profile.experienceLevel = level }
                }
            }
            .padding(24)
        }
    }
}

struct OnboardingLocationView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Location", subtitle: "Where do you train?")
                ForEach(TrainingLocation.allCases) { loc in
                    SelectableRow(title: loc.displayName, isSelected: viewModel.profile.trainingLocation == loc) {
                        viewModel.profile.trainingLocation = loc
                    }
                }
            }
            .padding(24)
        }
    }
}

struct OnboardingEquipmentView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Equipment", subtitle: "What do you have access to?")
                ForEach(Equipment.allCases) { eq in
                    MultiSelectRow(
                        title: eq.displayName,
                        isSelected: viewModel.profile.availableEquipment.contains(eq)
                    ) {
                        if viewModel.profile.availableEquipment.contains(eq) {
                            viewModel.profile.availableEquipment.removeAll { $0 == eq }
                        } else {
                            viewModel.profile.availableEquipment.append(eq)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct OnboardingScheduleView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let durations = [20, 30, 45, 60, 75, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForgeSectionHeader(title: "Schedule", subtitle: "Training frequency")
                Stepper("Days per week: \(viewModel.profile.trainingDaysPerWeek)", value: $viewModel.profile.trainingDaysPerWeek, in: 2...7)

                Text("Session length").font(ForgeTypography.heading)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(durations, id: \.self) { d in
                        SelectableChip(title: "\(d) min", isSelected: viewModel.profile.preferredSessionLengthMinutes == d) {
                            viewModel.profile.preferredSessionLengthMinutes = d
                        }
                    }
                }

                Text("Preferred days").font(ForgeTypography.heading)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(Weekday.allCases) { day in
                        SelectableChip(title: day.shortName, isSelected: viewModel.profile.preferredTrainingDays.contains(day)) {
                            if viewModel.profile.preferredTrainingDays.contains(day) {
                                viewModel.profile.preferredTrainingDays.removeAll { $0 == day }
                            } else {
                                viewModel.profile.preferredTrainingDays.append(day)
                            }
                        }
                    }
                }

                Picker("Time preference", selection: $viewModel.profile.timeOfDayPreference) {
                    ForEach(TimeOfDayPreference.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(24)
        }
    }
}

struct OnboardingBodyStatsView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var weightText = "80"
    @State private var heightText = "175"
    @State private var ageText = "30"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Body Stats", subtitle: "For programming and protein")
                ForgeTextField(label: "Weight (kg)", text: $weightText)
                    .onChange(of: weightText) { _, v in viewModel.profile.weightKg = Double(v) }
                ForgeTextField(label: "Height (cm)", text: $heightText)
                    .onChange(of: heightText) { _, v in viewModel.profile.heightCm = Double(v) }
                ForgeTextField(label: "Age", text: $ageText)
                    .onChange(of: ageText) { _, v in viewModel.profile.age = Int(v) }
            }
            .padding(24)
            .onAppear {
                weightText = String(format: "%.0f", viewModel.profile.weightKg ?? 80)
                heightText = String(format: "%.0f", viewModel.profile.heightCm ?? 175)
                ageText = String(viewModel.profile.age ?? 30)
            }
        }
    }
}

struct OnboardingLimitationsView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var notes = ""

    private var limitationOptions: [BodyLimitation] {
        [.none] + BodyLimitation.allCases.filter { $0 != .none }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Limitations", subtitle: "Any injuries or restrictions?")
                ForEach(limitationOptions) { lim in
                    MultiSelectRow(title: lim.displayName, isSelected: viewModel.profile.limitations.contains(lim)) {
                        if lim == .none {
                            viewModel.profile.limitations = [.none]
                        } else {
                            viewModel.profile.limitations.removeAll { $0 == .none }
                            if viewModel.profile.limitations.contains(lim) {
                                viewModel.profile.limitations.removeAll { $0 == lim }
                            } else {
                                viewModel.profile.limitations.append(lim)
                            }
                        }
                    }
                }
                ForgeTextField(label: "Notes (optional)", text: $notes)
                    .onChange(of: notes) { _, v in viewModel.profile.limitationNotes = v.isEmpty ? nil : v }
            }
            .padding(24)
        }
    }
}

struct OnboardingProteinView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var didInitialize = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Protein Target", subtitle: "Daily goal")
                let weight = viewModel.profile.weightKg ?? 80
                ForEach(ProteinGoalCalculator.rangeOptions(bodyWeightKg: weight), id: \.label) { option in
                    SelectableRow(
                        title: option.label,
                        subtitle: "\(Int(option.grams))g / day",
                        isSelected: Int(viewModel.profile.proteinGoalGrams) == Int(option.grams)
                    ) { viewModel.profile.proteinGoalGrams = option.grams }
                }
            }
            .padding(24)
            .onAppear {
                guard !didInitialize else { return }
                didInitialize = true
                viewModel.profile.proteinGoalGrams = ProteinGoalCalculator.suggestedGoal(
                    bodyWeightKg: viewModel.profile.weightKg ?? 80,
                    goal: viewModel.profile.goal
                )
            }
        }
    }
}

struct OnboardingPhotoView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForgeSectionHeader(title: "Progress Photos", subtitle: "Visual tracking")
            Text("Take consistent front, side, and back photos. The app will track visual changes over time. This is not a medical body-fat test.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
            ForgeButton(title: "Set Up Photo Tracking") { viewModel.profile.photoTrackingEnabled = true }
            ForgeButton(title: "Skip For Now", style: .secondary) { viewModel.profile.photoTrackingEnabled = false }
            Spacer()
        }
        .padding(24)
    }
}

struct OnboardingPlanView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForgeSectionHeader(title: "Plan Ready", subtitle: "Your starting point")
                MetricCard(label: "Split", value: viewModel.profile.preferredSplit.displayName)
                MetricCard(label: "Session", value: "\(viewModel.profile.preferredSessionLengthMinutes) min")
                MetricCard(label: "Protein", value: "\(Int(viewModel.profile.proteinGoalGrams))g")
                MetricCard(label: "Frequency", value: "\(viewModel.profile.trainingDaysPerWeek)x / week")
                Text("First milestone: Complete 4 workouts and hit protein 5 days in a row.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            }
            .padding(24)
        }
    }
}

struct OnboardingGoalView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Goal", subtitle: "What's your goal?")
                ForEach(TrainingGoal.allCases) { goal in
                    SelectableRow(title: goal.displayName, isSelected: viewModel.profile.goal == goal) {
                        viewModel.profile.goal = goal
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Shared onboarding components

struct SelectableRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(ForgeTypography.heading)
                    if let subtitle {
                        Text(subtitle).font(ForgeTypography.body).foregroundStyle(ForgeColors.muted)
                    }
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.square.fill").foregroundStyle(ForgeColors.accent) }
            }
            .padding(16)
            .overlay(Rectangle().stroke(isSelected ? ForgeColors.accent : ForgeColors.border, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ForgeColors.foreground)
    }
}

struct MultiSelectRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SelectableRow(title: title, isSelected: isSelected, action: action)
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ForgeTypography.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? ForgeColors.accentGradient : LinearGradient(colors: [ForgeColors.surface], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(chipForeground)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule().stroke(ForgeColors.border, lineWidth: 1)
                    }
                }
                .scaleEffect(isSelected ? 1.02 : 1)
                .opacity(isDisabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(ForgeMotion.quick, value: isSelected)
    }

    private var chipForeground: Color {
        if isDisabled { return ForgeColors.muted }
        return isSelected ? ForgeColors.surface : ForgeColors.foreground
    }
}

struct ForgeTextField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(ForgeTypography.caption).foregroundStyle(ForgeColors.muted)
            Group {
                if isSecure {
                    SecureField(label, text: $text)
                } else {
                    TextField(label, text: $text)
                }
            }
            .font(ForgeTypography.monoMetric)
            .keyboardType(keyboardType)
            .padding(12)
            .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
        }
    }
}
