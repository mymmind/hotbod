import SwiftUI

struct WorkoutCompletionView: View {
    @Environment(AppEnvironment.self) private var environment
    let session: WorkoutSession
    var progressionNotes: [String] = []
    var workoutStreak: Int = 0
    var exerciseMap: [String: Exercise] = [:]
    let onDone: () -> Void

    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var showAddPhoto = false
    @State private var selectedPose: BodyPhotoPoseType = .frontRelaxed
    @State private var isImportingPhoto = false
    @State private var photoImportMessage: String?
    @State private var photoImportSucceeded = false

    private var volume: Double {
        WorkoutSessionCalculator.completedVolumeKg(session: session)
    }

    private var duration: Int {
        guard let start = session.startedAt, let end = session.completedAt else {
            return session.estimatedDurationMinutes
        }
        return Int(end.timeIntervalSince(start) / 60)
    }

    private var muscleSummary: String {
        WorkoutSessionCalculator.trainedMuscleGroups(session: session, exerciseMap: exerciseMap)
            .map(\.displayName)
            .joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ForgeSpacing.s5) {
                ForgeHeroCard(
                    eyebrow: L10n.Workout.completeTitle,
                    title: session.title,
                    badge: workoutStreak > 0 ? "\(workoutStreak)-day streak" : nil,
                    completed: true,
                    completionMetrics: [
                        (label: "Volume", value: "\(Int(volume))kg"),
                        (label: "Sets", value: "\(WorkoutSessionCalculator.completedSetCount(session: session))"),
                        (label: "Duration", value: "\(duration) min")
                    ],
                    inverted: true,
                    fullBleedTop: false
                )

                if !muscleSummary.isEmpty {
                    ForgeCard {
                        ForgeSectionHeader(title: "Muscles trained")
                        Text(muscleSummary)
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.textSecondary)
                    }
                }

                if !progressionNotes.isEmpty {
                    ForgeCard {
                        ForgeSectionHeader(title: "Progression", accent: ForgeColors.accentGreen)
                        ForEach(progressionNotes, id: \.self) { note in
                            Text("· \(note)")
                                .font(ForgeTypography.body)
                                .foregroundStyle(ForgeColors.textSecondary)
                        }
                    }
                }

                if environment.isPhotoTrackingEnabled {
                    ForgeCard {
                        ForgeSectionHeader(title: "Progress photo", subtitle: selectedPose.displayName)
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
                }

                if let photoImportMessage {
                    Text(photoImportMessage)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(photoImportSucceeded ? ForgeColors.accentGreen : ForgeColors.destructive)
                }

                VStack(spacing: ForgeSpacing.s3) {
                    ForgeButton(
                        title: "Share Workout",
                        style: .secondary,
                        accessibilityIdentifier: "session.shareWorkout"
                    ) {
                        shareCompletedWorkout()
                    }

                    if environment.isPhotoTrackingEnabled {
                        ForgeButton(
                            title: "Add Progress Photo",
                            style: .secondary,
                            isLoading: isImportingPhoto,
                            accessibilityIdentifier: "session.addProgressPhoto"
                        ) {
                            showAddPhoto = true
                        }
                    }

                    ForgeButton(
                        title: "Done",
                        style: .accent,
                        accessibilityIdentifier: "session.finishWorkout",
                        action: onDone
                    )
                }
            }
            .padding(.horizontal, ForgeSpacing.s5)
            .padding(.vertical, ForgeSpacing.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForgeColors.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.workoutComplete")
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
        .bodyPhotoAddPhoto(
            isPresented: $showAddPhoto,
            onImageData: { data in
                await importProgressPhoto(data)
            },
            onFailure: { message in
                photoImportSucceeded = false
                photoImportMessage = message
            }
        )
    }

    private func shareCompletedWorkout() {
        guard environment.canAccess(.workoutExport) else {
            environment.presentPaywall(for: .workoutExport)
            return
        }

        let card = WorkoutShareCard(
            title: session.title,
            volumeKg: Int(volume),
            sets: WorkoutSessionCalculator.completedSetCount(session: session),
            durationMinutes: duration,
            workoutStreak: workoutStreak,
            muscleSummary: muscleSummary.isEmpty ? nil : muscleSummary
        )
        shareImage = WorkoutShareRenderer.image(for: card)
        showShareSheet = shareImage != nil
    }

    private func importProgressPhoto(_ data: Data) async {
        guard let userId = environment.userProfile?.id else { return }
        isImportingPhoto = true
        defer { isImportingPhoto = false }
        do {
            _ = try await environment.importBodyPhoto(
                imageData: data,
                userId: userId,
                pose: selectedPose,
                weightKg: environment.userProfile?.weightKg
            )
            photoImportSucceeded = true
            photoImportMessage = "Progress photo saved."
        } catch {
            photoImportSucceeded = false
            photoImportMessage = "Could not save photo."
        }
    }
}
