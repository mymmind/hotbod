import SwiftUI
import UIKit

struct PhysiqueIllustrationSection: View {
    @Environment(AppEnvironment.self) private var environment
    let assessment: PhysiqueAssessment
    let photos: [BodyProgressPhoto]

    @State private var resolvedPhotos: [BodyProgressPhoto] = []
    @State private var hasResolvedPhotoAvailability = false

    private var effectivePhotos: [BodyProgressPhoto] {
        photos.isEmpty ? resolvedPhotos : photos
    }

    private var hasFrontPhotoForIllustration: Bool {
        guard let frontPhoto = effectivePhotos.first(where: { $0.id == assessment.frontPhotoId }) else {
            return false
        }
        return BodyPhotoImageProcessor.fileExists(at: frontPhoto.localImagePath)
    }

    private var canGenerateIllustration: Bool {
        !hasResolvedPhotoAvailability || hasFrontPhotoForIllustration
    }

    var body: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                if let imageData = environment.physiqueIllustrationImageData,
                   let uiImage = UIImage(data: imageData) {
                    resultView(uiImage)
                } else {
                    readyView
                }

                if let status = environment.physiqueIllustrationStatus {
                    Text(status)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: assessment.id) {
            resolvedPhotos = await environment.fetchBodyPhotos()
            hasResolvedPhotoAvailability = true
            await environment.loadPhysiqueIllustration(for: assessment.id)
        }
    }

    private var readyView: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("Subtle emphasis of your current focus areas. Not a prediction.")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasResolvedPhotoAvailability && !hasFrontPhotoForIllustration {
                Text("Add a front photo to generate.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForgeButton(
                title: "Generate illustrative direction",
                style: .secondary,
                isLoading: environment.isGeneratingPhysiqueIllustration,
                isEnabled: canGenerateIllustration,
                accessibilityIdentifier: "physique.illustrate"
            ) {
                Task {
                    await environment.generatePhysiqueIllustration(
                        assessment: assessment,
                        photos: effectivePhotos
                    )
                }
            }
        }
    }

    private func resultView(_ uiImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            ForgeSectionHeader(title: "Illustrative direction", subtitle: nil)

            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Illustrative direction image")

            Text("This is an illustration of possible emphasis — not a forecast of your body, timeline, or genetics.")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForgeButton(
                title: "Regenerate",
                style: .secondary,
                isLoading: environment.isGeneratingPhysiqueIllustration,
                isEnabled: canGenerateIllustration,
                accessibilityIdentifier: "physique.illustrate.regenerate"
            ) {
                Task {
                    await environment.generatePhysiqueIllustration(
                        assessment: assessment,
                        photos: effectivePhotos
                    )
                }
            }
        }
        .accessibilityIdentifier("physique.illustrate.result")
    }
}

#Preview {
    PhysiqueIllustrationSection(
        assessment: PreviewFixtures.physiqueAssessment,
        photos: []
    )
    .padding(ForgeSpacing.s5)
    .background(ForgeColors.background)
    .environment(AppEnvironment())
}

private enum PreviewFixtures {
    static var physiqueAssessment: PhysiqueAssessment {
        PhysiqueAssessment(
            id: UUID(),
            createdAt: Date(),
            frontPhotoId: UUID(),
            backPhotoId: UUID(),
            sidePhotoId: nil,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.72
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: "Athletic build",
                frameSize: "Medium",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [],
            developmentPriorities: [
                PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Caps")
            ],
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: [.shoulders, .back],
                rationale: "Frame balance."
            ),
            limitations: [],
            confidenceBands: PhysiqueConfidenceBands(high: [], medium: [], low: []),
            source: .onDevice,
            whyTodaySummary: "Bias shoulders and back."
        )
    }
}
