import SwiftUI

struct CoachView: View {
    enum Presentation {
        case tab
        case navigationPush
        case routerOverlay
    }

    var presentation: Presentation = .tab

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.forgeFeedback) private var feedback
    @State private var messages: [CoachMessage] = []
    @State private var input = ""
    @State private var isSending = false
    @State private var pendingCoachResult: CoachAIResult?

    private let suggestions = [
        "Why am I doing this workout today?",
        "Make this workout 30 minutes.",
        "Shoulder discomfort - adjust exercises.",
        "How much protein do I still need?"
    ]

    private var showsRouterDismiss: Bool {
        presentation == .routerOverlay
    }

    var body: some View {
        Group {
            if presentation == .tab {
                NavigationStack { coachBody }
            } else {
                coachBody
            }
        }
        .accessibilityIdentifier("coach.root")
    }

    private var coachBody: some View {
        VStack(spacing: 0) {
            if let banner = environment.coachWorkoutUpdateMessage {
                Text(banner)
                    .font(ForgeTypography.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(ForgeColors.accent)
                    .foregroundStyle(ForgeColors.surface)
            }

            ForgeScreenHeader(
                title: "Coach",
                style: showsRouterDismiss ? .compact : .root,
                eyebrow: coachConnectionLabel,
                subtitle: "Ask for swaps, adjustments, and training advice.",
                leading: {
                    if showsRouterDismiss {
                        ForgeHeaderBackButton { router.dismissRoute() }
                    }
                }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                        if messages.isEmpty {
                            VStack(alignment: .leading, spacing: ForgeSpacing.s2) {
                                Text("Ask your coach")
                                    .font(ForgeTypography.title)
                                ForEach(suggestions, id: \.self) { s in
                                    Button(s) { input = s; Task { await send() } }
                                        .font(ForgeTypography.body)
                                        .foregroundStyle(ForgeColors.textSecondary)
                                        .frame(maxWidth: .infinity, minHeight: ForgeTarget.min, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier(coachSuggestionIdentifier(for: s))
                                }
                            }
                            .padding(ForgeSpacing.s4)
                        }
                        ForEach(messages) { msg in
                            messageBubble(msg).id(msg.id)
                        }
                    }
                    .padding(ForgeSpacing.s4)
                }
                .forgeFloatingTabBarClearance(enabled: presentation == .tab)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let pending = pendingCoachResult, let workout = pending.proposedWorkout {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coach proposed: \(workout.title)")
                        .font(ForgeTypography.body.weight(.semibold))
                    if let validation = pending.validation, !validation.warnings.isEmpty {
                        ForEach(validation.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                    }
                    HStack {
                        Button("Apply") {
                            Task {
                                let applied = await environment.applyAIWorkout(workout, serverValidation: pending.validation)
                                if applied {
                                    feedback.play(.coachApply)
                                    pendingCoachResult = nil
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ForgeColors.accent)
                        Button("Not now") { pendingCoachResult = nil }
                    }
                }
                .padding()
                .background(ForgeColors.surface)
                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
                .padding(.horizontal)
                .transition(ForgeMotion.rise)
                .forgeValidationShake(value: pending.validation?.warnings.count ?? 0)
            }

            HStack(spacing: ForgeSpacing.s2) {
                TextField("Ask coach...", text: $input)
                    .padding(ForgeSpacing.s3)
                    .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
                    .accessibilityIdentifier("coach.input")
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ForgeColors.accent)
                }
                .forgeMinTapTarget()
                .accessibilityLabel("Send message")
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(ForgeSpacing.s4)
            .padding(.bottom, presentation == .tab ? 0 : 0)
        }
        .background(ForgeColors.background)
        .forgeScreenNavigationHidden()
        .navigationBarBackButtonHidden(showsRouterDismiss)
        .toolbar(presentation == .tab ? .visible : .automatic, for: .tabBar)
        .animation(ForgeMotion.standard, value: pendingCoachResult?.proposedWorkout?.id)
        .task { await loadMessages() }
        .onChange(of: environment.coachWorkoutUpdateMessage) { _, message in
            guard message != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(3))
                environment.coachWorkoutUpdateMessage = nil
            }
        }
    }


    private var coachConnectionLabel: String {
        if environment.isSupabaseConfigured {
            return environment.isSignedIn ? "Online" : "Sign in for full coach"
        }
        if GeminiConfig.isConfigured {
            return "AI Coach"
        }
        return "On-device coach"
    }

    private func messageBubble(_ msg: CoachMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer() }
            Text(msg.content)
                .font(ForgeTypography.body)
                .padding(12)
                .background(msg.role == .user ? ForgeColors.accent : ForgeColors.surface)
                .foregroundStyle(msg.role == .user ? ForgeColors.surface : ForgeColors.foreground)
                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: msg.role == .assistant ? 1 : 0))
                .frame(maxWidth: 280, alignment: msg.role == .user ? .trailing : .leading)
                .accessibilityIdentifier(msg.role == .assistant ? "coach.assistantMessage" : "coach.userMessage")
            if msg.role == .assistant { Spacer() }
        }
    }

    private func playCoachProposalWarningIfNeeded(_ result: CoachAIResult) {
        guard let warnings = result.validation?.warnings, !warnings.isEmpty else { return }
        feedback.play(.warning)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        let userMsg = CoachMessage(id: UUID(), role: .user, content: text, createdAt: Date())
        messages.append(userMsg)
        try? await environment.saveCoachMessage(userMsg)
        input = ""

        let proteinSummary = await environment.proteinSummary()
        let exercises = await environment.fetchAllExercises()
        let profile = environment.userProfile
        let photos = await environment.fetchBodyPhotos()
        let sortedPhotos = BodyProgressPhoto.sortedByDateDescending(photos)

        let context = CoachContext(
            userProfile: UserProfileSummary(
                goal: profile?.goal ?? .buildMuscle,
                experienceLevel: profile?.experienceLevel ?? .intermediate,
                proteinGoalGrams: profile?.proteinGoalGrams ?? 145
            ),
            currentWorkout: environment.todayWorkout,
            recentWorkouts: await environment.fetchSessionSummaries(),
            exerciseStats: await environment.fetchExerciseStats(),
            proteinSummary: proteinSummary,
            bodyProgressSummary: BodyProgressSummary(
                photoCount: photos.count,
                latestPhotoDate: sortedPhotos.first?.date,
                averageLightingScore: BodyProgressPhoto.averageLightingScore(in: photos)
            ),
            recovery: RecoveryCalculator.recoveryMap(from: environment.recoveryStates),
            limitations: profile?.limitations ?? [],
            allowedExerciseIds: exercises.map(\.id),
            availableEquipment: profile?.availableEquipment ?? Equipment.allCases,
            targetDurationMinutes: profile?.preferredSessionLengthMinutes ?? 45
        )

        if let result = try? await environment.aiWorkoutService.respond(to: text, context: context) {
            messages.append(result.message)
            try? await environment.saveCoachMessage(result.message)
            feedback.play(.success)
            if let workout = result.proposedWorkout {
                let autoApplied = await environment.tryAutoApplyCoachModification(
                    result: result,
                    allowedExerciseIds: exercises.map(\.id)
                )
                if !autoApplied {
                    pendingCoachResult = result
                    playCoachProposalWarningIfNeeded(result)
                }
            } else {
                await handleCoachAction(intent: result.message.intent, userMessage: text, profile: profile)
            }
        }
        isSending = false
    }

    private func handleCoachAction(intent: CoachIntent?, userMessage: String, profile: UserProfile?) async {
        guard intent == .modifyWorkout, let profile else { return }

        if await environment.blocksCoachWorkoutModification() {
            let msg = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: "Finish or discard your current session before applying coach changes.",
                createdAt: Date(),
                intent: .modifyWorkout
            )
            messages.append(msg)
            try? await environment.saveCoachMessage(msg)
            return
        }

        if let restMessage = CoachOfflineModify.restDayMessage(profile: profile) {
            let msg = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: restMessage,
                createdAt: Date(),
                intent: .modifyWorkout
            )
            messages.append(msg)
            try? await environment.saveCoachMessage(msg)
            return
        }

        let options = CoachOfflineModify.generationOptions(from: userMessage, profile: profile)
        let updated = await environment.regenerateTodayWorkout(profile: profile, options: options)
        if updated {
            feedback.play(.workoutRegenerate)
            environment.coachWorkoutUpdateMessage = "Workout updated"
        }
    }

    private func loadMessages() async {
        messages = await environment.fetchCoachMessages()
    }

    private func coachSuggestionIdentifier(for suggestion: String) -> String {
        switch suggestion {
        case "How much protein do I still need?": "coach.suggestion.protein"
        case "Why am I doing this workout today?": "coach.suggestion.workout"
        case "Make this workout 30 minutes.": "coach.suggestion.shorter"
        default: "coach.suggestion.adjust"
        }
    }
}
