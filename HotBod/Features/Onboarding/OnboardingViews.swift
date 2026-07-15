import SwiftUI
import UIKit
import PhotosUI
import Observation

struct OnboardingContainerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var completionError: String?

    private var viewModel: OnboardingViewModel {
        environment.onboardingViewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ProgressView(value: viewModel.progress)
                .tint(ForgeColors.accent)
                .padding(.horizontal)
                .padding(.top, 8)

            Group {
                switch viewModel.step {
                case 0: OnboardingWelcomeView(viewModel: viewModel).forgeAnimatedContent(id: 0)
                case 1: OnboardingGoalView(viewModel: viewModel).forgeAnimatedContent(id: 1)
                case 2: OnboardingExperienceView(viewModel: viewModel).forgeAnimatedContent(id: 2)
                case 3: OnboardingLocationView(viewModel: viewModel).forgeAnimatedContent(id: 3)
                case 4: OnboardingEquipmentView(viewModel: viewModel).forgeAnimatedContent(id: 4)
                case 5: OnboardingScheduleView(viewModel: viewModel).forgeAnimatedContent(id: 5)
                case 6: OnboardingBodyStatsView(viewModel: viewModel).forgeAnimatedContent(id: 6)
                case 7: OnboardingLimitationsView(viewModel: viewModel).forgeAnimatedContent(id: 7)
                case 8: OnboardingProteinView(viewModel: viewModel).forgeAnimatedContent(id: 8)
                case 9: OnboardingPhotoView(viewModel: viewModel).forgeAnimatedContent(id: 9)
                default: OnboardingPlanView(viewModel: viewModel).forgeAnimatedContent(id: 10)
                }
            }
            .id(viewModel.step)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.step.\(viewModel.step)")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: viewModel.step)
            .disabled(viewModel.isCompleting)

            if let completionError {
                Text(completionError)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.destructive)
                    .padding(.horizontal)
            }

            onboardingFooter(viewModel: viewModel)
        }
        .background(ForgeColors.background)
        .onChange(of: viewModel.step) { _, _ in
            dismissKeyboard()
            completionError = nil
        }
        .task {
            guard UITestConfiguration.shouldAutoFinishOnboarding else { return }
            await completeOnboarding()
        }
    }

    @ViewBuilder
    private func onboardingFooter(viewModel: OnboardingViewModel) -> some View {
        HStack(spacing: 12) {
            if viewModel.step > 0 {
                onboardingFooterButton(
                    title: "Back",
                    identifier: "onboarding.back",
                    style: .secondary,
                    isEnabled: !viewModel.isCompleting
                ) { viewModel.back() }
            }
            onboardingFooterButton(
                title: viewModel.step == 10 ? "Start Today's Workout" : "Continue",
                identifier: viewModel.step == 10 ? "onboarding.startWorkout" : "onboarding.continue",
                style: .accent,
                isEnabled: !viewModel.isCompleting,
                isLoading: viewModel.isCompleting
            ) {
                if viewModel.step == 10 {
                    Task { await completeOnboarding() }
                } else {
                    let nextStep = min(viewModel.step + 1, 10)
                    viewModel.step = nextStep
                }
            }
        }
        .padding()
        .background(ForgeColors.background)
    }

    @ViewBuilder
    private func onboardingFooterButton(
        title: String,
        identifier: String,
        style: ForgeButtonStyle,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if UITestConfiguration.isUITesting {
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                    }
                    Text(title.uppercased())
                        .font(style == .accent ? ForgeTypography.cta : ForgeTypography.label)
                        .tracking(style == .accent ? ForgeTracking.cta : ForgeTracking.tight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, style == .accent ? 18 : ForgeSpacing.s4)
                        .background(style == .accent ? AnyView(ForgeColors.accentGradient) : AnyView(ForgeColors.surface))
                        .foregroundStyle(style == .accent ? ForgeColors.textOnInverse : ForgeColors.textPrimary)
                        .clipShape(RoundedRectangle.forge(style == .accent ? ForgeRadius.pill : ForgeRadius.none))
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isLoading)
            .opacity(isEnabled && !isLoading ? 1 : 0.4)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
        } else {
            ForgeButton(
                title: title,
                style: style,
                isLoading: isLoading,
                isEnabled: isEnabled,
                accessibilityIdentifier: identifier,
                action: action
            )
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func completeOnboarding() async {
        guard !viewModel.isCompleting else { return }
        completionError = nil
        viewModel.isCompleting = true
        defer { viewModel.isCompleting = false }

        if let session = await environment.finishOnboardingAndStartTodayWorkout(
            profile: viewModel.profile,
            lockSplit: viewModel.hasManualSplitSelection
        ) {
            viewModel.profile = environment.userProfile ?? viewModel.profile
            await WorkoutStartFlow.routeAfterStart(session, environment: environment, router: router)
            return
        }

        viewModel.profile = environment.userProfile ?? viewModel.profile
        guard environment.hasCompletedOnboarding else {
            completionError = environment.syncMessage ?? "Could not finish onboarding. Please try again."
            return
        }

        if environment.hasCompletedOnboarding,
           let profile = environment.userProfile,
           !TrainingSchedule.isTrainingDay(profile: profile) {
            router.showMain()
            return
        }

        if environment.todayWorkout != nil {
            router.showMain()
        } else {
            completionError = environment.syncMessage
                ?? "Could not start today's workout. Try again or open Today to regenerate."
        }
    }
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step = 0
    var profile = UserProfile.empty()
    var isCompleting = false
    var hasManualProteinSelection = false
    var hasManualSplitSelection = false

    init() {
        if let preset = UITestConfiguration.onboardingPreset {
            applyPreset(preset)
        } else if let startStep = UITestConfiguration.onboardingStartStep {
            step = min(max(startStep, 0), 10)
        }
    }

    private func applyPreset(_ preset: String) {
        switch preset {
        case "readyToFinish":
            profile.goal = .buildMuscle
            profile.experienceLevel = .intermediate
            profile.trainingLocation = .commercialGym
            profile.availableEquipment = [.barbell, .dumbbell, .bench, .cable, .machine]
            profile.trainingDaysPerWeek = 4
            profile.preferredTrainingDays = [.monday, .tuesday, .thursday, .friday]
            profile.weightKg = 80
            profile.heightCm = 178
            profile.age = 30
            profile.proteinGoalGrams = 160
            profile.limitations = []
            step = 10
        case "goalStep":
            step = 1
        case "afterGoal":
            profile.goal = .buildMuscle
            step = 2
        case "photoStep":
            profile.goal = .buildMuscle
            profile.experienceLevel = .intermediate
            profile.trainingLocation = .commercialGym
            profile.availableEquipment = [.barbell, .dumbbell, .bench, .cable, .machine]
            profile.trainingDaysPerWeek = 4
            profile.preferredTrainingDays = [.monday, .tuesday, .thursday, .friday]
            profile.weightKg = 80
            profile.heightCm = 178
            profile.age = 30
            profile.proteinGoalGrams = 160
            profile.limitations = []
            step = 9
        default:
            break
        }
    }

    var progress: Double { Double(step + 1) / 11.0 }

    func next() {
        if UITestConfiguration.isUITesting {
            step = min(step + 1, 10)
        } else {
            withAnimation(ForgeMotion.standard) { step = min(step + 1, 10) }
        }
    }

    func back() {
        if UITestConfiguration.isUITesting {
            step = max(step - 1, 0)
        } else {
            withAnimation(ForgeMotion.standard) { step = max(step - 1, 0) }
        }
    }

    /// Read-only preview for the plan summary — does not mutate the draft profile.
    var planPreviewProfile: UserProfile {
        var preview = profile
        OnboardingProfileEditing.normalizeForCompletion(
            &preview,
            lockSplit: hasManualSplitSelection
        )
        return preview
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
                        accessibilityIdentifier: "onboarding.experience.\(level.rawValue)",
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
                    SelectableRow(
                        title: loc.displayName,
                        accessibilityIdentifier: "onboarding.location.\(loc.rawValue)",
                        isSelected: viewModel.profile.trainingLocation == loc
                    ) {
                        OnboardingProfileEditing.applyLocation(loc, to: &viewModel.profile)
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
                        accessibilityIdentifier: "onboarding.equipment.\(eq.rawValue)",
                        isSelected: viewModel.profile.availableEquipment.contains(eq)
                    ) {
                        OnboardingProfileEditing.toggleEquipment(eq, in: &viewModel.profile)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct OnboardingScheduleView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let durations = GenerationConstants.Session.preferredSessionLengthOptions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForgeSectionHeader(title: "Schedule", subtitle: "Training frequency")
                Text("\(viewModel.profile.preferredTrainingDays.count) days per week")
                    .font(ForgeTypography.body)

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
                            if OnboardingProfileEditing.toggleTrainingDay(day, in: &viewModel.profile) {
                                applyAutomaticSplitIfNeeded()
                            }
                        }
                    }
                }

                Text("Training split").font(ForgeTypography.heading)
                Text("Suggested for \(viewModel.profile.trainingDaysPerWeek) days per week.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(TrainingSplit.selectableSplits) { split in
                        SelectableChip(title: split.displayName, isSelected: viewModel.profile.preferredSplit == split) {
                            viewModel.hasManualSplitSelection = true
                            viewModel.profile.preferredSplit = split
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
            .onAppear {
                if !viewModel.hasManualSplitSelection {
                    OnboardingProfileEditing.applySuggestedSplit(to: &viewModel.profile)
                }
            }
        }
    }

    private func applyAutomaticSplitIfNeeded() {
        guard !viewModel.hasManualSplitSelection else { return }
        OnboardingProfileEditing.applySuggestedSplit(to: &viewModel.profile)
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
                ForgeTextField(label: "Weight (kg)", text: $weightText, keyboardType: .decimalPad)
                ForgeTextField(label: "Height (cm)", text: $heightText, keyboardType: .numberPad)
                ForgeTextField(label: "Age", text: $ageText, keyboardType: .numberPad)
            }
            .padding(24)
            .onAppear { syncTextFieldsFromProfile() }
            .onChange(of: weightText) { _, _ in syncProfileFromTextFields() }
            .onChange(of: heightText) { _, _ in syncProfileFromTextFields() }
            .onChange(of: ageText) { _, _ in syncProfileFromTextFields() }
        }
    }

    private func syncTextFieldsFromProfile() {
        OnboardingProfileEditing.normalizeBodyStats(&viewModel.profile)
        weightText = String(format: "%.0f", viewModel.profile.weightKg ?? OnboardingProfileEditing.defaultWeightKg)
        heightText = String(format: "%.0f", viewModel.profile.heightCm ?? OnboardingProfileEditing.defaultHeightCm)
        ageText = String(viewModel.profile.age ?? OnboardingProfileEditing.defaultAge)
    }

    private func syncProfileFromTextFields() {
        OnboardingProfileEditing.applyBodyStatsText(
            weightText: weightText,
            heightText: heightText,
            ageText: ageText,
            to: &viewModel.profile
        )
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
                        SettingsDraftEditing.toggleLimitation(lim, in: &viewModel.profile)
                    }
                }
                ForgeTextField(label: "Notes (optional)", text: $notes)
                    .onChange(of: notes) { _, v in viewModel.profile.limitationNotes = v.isEmpty ? nil : v }
            }
            .padding(24)
            .onAppear {
                OnboardingProfileEditing.normalizeLimitations(&viewModel.profile)
                notes = viewModel.profile.limitationNotes ?? ""
            }
        }
    }
}

struct OnboardingProteinView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeSectionHeader(title: "Protein Target", subtitle: "Daily goal")
                let weight = viewModel.profile.weightKg ?? OnboardingProfileEditing.defaultWeightKg
                let suggested = OnboardingProfileEditing.suggestedProteinGoal(for: viewModel.profile)
                ForEach(ProteinGoalCalculator.rangeOptions(bodyWeightKg: weight), id: \.label) { option in
                    SelectableRow(
                        title: option.label,
                        subtitle: "\(Int(option.grams))g / day",
                        isSelected: Int(viewModel.profile.proteinGoalGrams) == Int(option.grams)
                    ) {
                        viewModel.hasManualProteinSelection = true
                        viewModel.profile.proteinGoalGrams = option.grams
                    }
                }
                if viewModel.hasManualProteinSelection {
                    ForgeButton(title: "Use Suggested Goal (\(Int(suggested))g)", style: .secondary) {
                        viewModel.hasManualProteinSelection = false
                        viewModel.profile.proteinGoalGrams = suggested
                    }
                }
            }
            .padding(24)
            .onAppear { refreshSuggestedGoalIfNeeded() }
            .onChange(of: viewModel.profile.weightKg) { _, _ in refreshSuggestedGoalIfNeeded() }
            .onChange(of: viewModel.profile.goal) { _, _ in refreshSuggestedGoalIfNeeded() }
        }
    }

    private func refreshSuggestedGoalIfNeeded() {
        guard !viewModel.hasManualProteinSelection else { return }
        viewModel.profile.proteinGoalGrams = OnboardingProfileEditing.suggestedProteinGoal(for: viewModel.profile)
    }
}

struct OnboardingPhotoView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: OnboardingViewModel
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedPose: BodyPhotoPoseType = .frontRelaxed
    @State private var importedPhotoPath: String?
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForgeSectionHeader(title: "Progress Photos", subtitle: "Visual tracking")
                Text("Take consistent front, side, and back photos. The app will track visual changes over time. This is not a medical body-fat test.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)

                poseSelector

                if let importError {
                    Text(importError)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.destructive)
                }

                if let path = importedPhotoPath, let uiImage = UIImage(contentsOfFile: path) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FIRST PHOTO SAVED")
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.accentGreen)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle.forge(ForgeRadius.sm))
                    }
                }

                ForgeButton(
                    title: importedPhotoPath == nil ? "Set Up Photo Tracking" : "Add Another Photo",
                    style: .accent,
                    isLoading: isImporting,
                    accessibilityIdentifier: "onboarding.photo.setup"
                ) {
                    importError = nil
                    viewModel.profile.photoTrackingEnabled = true
                    showPicker = true
                }
                ForgeButton(
                    title: "Skip For Now",
                    style: .secondary,
                    accessibilityIdentifier: "onboarding.photo.skip"
                ) {
                    importError = nil
                    if importedPhotoPath != nil {
                        viewModel.profile.photoTrackingEnabled = true
                    } else {
                        viewModel.profile.photoTrackingEnabled = false
                        pickerItem = nil
                    }
                }
            }
            .padding(24)
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            Task { await importPhoto(item) }
        }
        .task { await loadExistingPhotos() }
    }

    private var poseSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(BodyPhotoPoseType.allCases) { pose in
                    SelectableChip(title: pose.displayName, isSelected: selectedPose == pose) {
                        selectedPose = pose
                    }
                }
            }
        }
    }

    private func loadExistingPhotos() async {
        let photos = await environment.fetchBodyPhotos(forUserId: viewModel.profile.id)
        guard let latest = BodyProgressPhoto.sortedByDateDescending(photos).first else { return }
        importedPhotoPath = latest.localImagePath
        selectedPose = latest.poseType
        viewModel.profile.photoTrackingEnabled = true
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isImporting = true
        importError = nil
        defer {
            isImporting = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "Could not load that photo. Try a different image."
                return
            }
            let photo = try await environment.importBodyPhoto(
                imageData: data,
                userId: viewModel.profile.id,
                pose: selectedPose,
                weightKg: viewModel.profile.weightKg
            )
            importedPhotoPath = photo.localImagePath
            viewModel.profile.photoTrackingEnabled = true
        } catch {
            importError = "Could not save photo. Check storage space and try again."
        }
    }
}

struct OnboardingPlanView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var preview: UserProfile { viewModel.planPreviewProfile }

    private var scheduleSummary: String {
        if preview.preferredTrainingDays.isEmpty {
            return "\(preview.trainingDaysPerWeek)x / week · flexible days"
        }
        let days = preview.preferredTrainingDays.map(\.shortName).joined(separator: ", ")
        return "\(preview.trainingDaysPerWeek)x / week · \(days)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForgeSectionHeader(title: "Plan Ready", subtitle: "Your starting point")
                MetricCard(label: "Split", value: preview.preferredSplit.displayName)
                MetricCard(label: "Session", value: "\(preview.preferredSessionLengthMinutes) min")
                MetricCard(label: "Protein", value: "\(Int(preview.proteinGoalGrams))g")
                MetricCard(label: "Frequency", value: scheduleSummary)
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
                    .accessibilityIdentifier("onboarding.goal.header")
                ForEach(TrainingGoal.allCases) { goal in
                    SelectableRow(
                        title: goal.displayName,
                        accessibilityIdentifier: "onboarding.goal.\(goal.rawValue)",
                        isSelected: viewModel.profile.goal == goal
                    ) {
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
    var accessibilityIdentifier: String? = nil
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
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct MultiSelectRow: View {
    let title: String
    var accessibilityIdentifier: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SelectableRow(
            title: title,
            accessibilityIdentifier: accessibilityIdentifier,
            isSelected: isSelected,
            action: action
        )
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
