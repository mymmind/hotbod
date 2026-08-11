import SwiftUI

struct PhysiqueView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var photos: [BodyProgressPhoto] = []
    @State private var gateResult: PhysiquePhotoGateResult?
    @State private var isAssessing = false
    @State private var hasStalePhotos = false
    @State private var showAddPhoto = false
    @State private var addPhotoPose: BodyPhotoPoseType = .frontRelaxed
    @State private var isImporting = false
    @State private var importError: String?

    private var assessment: PhysiqueAssessment? {
        environment.activePhysiqueAssessment
    }

    private var headerEyebrow: String? {
        guard let assessment else { return nil }
        return assessment.source == .cloud ? "Online" : "On-device estimate"
    }

    private var isCadenceDue: Bool {
        guard let assessment else { return false }
        return PhysiqueReassessCadence.isDue(assessmentCreatedAt: assessment.createdAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForgeScreenHeader(
                        title: "Physique",
                        eyebrow: headerEyebrow,
                        subtitle: "Photo assessment and training focus."
                    )

                    VStack(spacing: ForgeSpacing.s4) {
                        if hasStalePhotos {
                            staleBanner
                        }
                        if isCadenceDue {
                            cadenceDueBanner
                        }

                        if let status = environment.physiqueStatusMessage {
                            statusBanner(status)
                        }

                        if let importError {
                            Text(importError)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if isAssessing {
                            assessingSection
                        }

                        if let assessment {
                            reportSection(assessment)
                        } else {
                            gateSection
                        }
                    }
                    .padding(ForgeSpacing.s5)
                }
            }
            .background(ForgeColors.background)
            .forgeFloatingTabBarClearance()
            .forgeScreenNavigationHidden()
        }
        .accessibilityIdentifier("physique.root")
        .bodyPhotoAddPhoto(
            isPresented: $showAddPhoto,
            onImageData: { data in
                await importPhotoData(data)
            },
            onFailure: { message in
                importError = message
            }
        )
        .task(id: environment.bodyPhotoRevision) {
            await refresh()
        }
        .task(id: environment.hasCompletedBootstrap) {
            guard environment.hasCompletedBootstrap else { return }
            await environment.loadActivePhysiqueAssessment()
        }
        .onAppear {
            Task { await environment.loadActivePhysiqueAssessment() }
        }
    }

    // MARK: - Sections

    private var staleBanner: some View {
        ForgeCard {
            Text("Newer photos available — reassess to refresh your focus.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private var cadenceDueBanner: some View {
        ForgeCard {
            Text("6 weeks since last assessment — reassess to refresh your focus.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
        }
        .accessibilityIdentifier("physique.cadenceDue")
    }

    private func statusBanner(_ message: String) -> some View {
        ForgeCard {
            Text(message)
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private var assessingSection: some View {
        ForgeCard {
            HStack(spacing: ForgeSpacing.s3) {
                ProgressView()
                Text("Assessing photos…")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var gateSection: some View {
        switch gateResult {
        case .qualityFailed(let failures):
            needsRetakeSection(failures: failures)
        case .missingAngles(let angles):
            emptySection(missingAngles: angles)
        case .ready:
            readyToAssessSection
        case nil:
            emptySection(missingAngles: [.front])
        }
    }

    private func emptySection(missingAngles: [PhysiquePhotoAngle]) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                Text(emptyMessage(missingAngles: missingAngles))
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
                    .accessibilityIdentifier("physique.empty")

                photoActionButtons(missingAngles: missingAngles)
            }
        }
    }

    private func needsRetakeSection(failures: [(angle: PhysiquePhotoAngle, reason: String)]) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                Text("Photo quality needs a retake.")
                    .font(ForgeTypography.heading)

                ForEach(failures, id: \.angle) { failure in
                    Text("\(failure.angle.rawValue.capitalized): \(failure.reason)")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }

                photoActionButtons(missingAngles: failures.map(\.angle))
            }
        }
    }

    private var readyToAssessSection: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                Text("Front photo ready.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)

                if !hasBackPhoto || !hasSidePhoto {
                    Text("Add back and side photos for a fuller read.")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }

                if !hasBackPhoto {
                    ForgeButton(title: "Add Back Photo", style: .secondary) {
                        presentAddPhoto(for: .back)
                    }
                }

                if !hasSidePhoto {
                    ForgeButton(title: "Add Side Photo", style: .secondary) {
                        presentAddPhoto(for: .side)
                    }
                }

                ForgeButton(
                    title: "Assess",
                    style: .accent,
                    isLoading: isAssessing
                ) {
                    Task { await runAssessment() }
                }
            }
        }
    }

    private func reportSection(_ assessment: PhysiqueAssessment) -> some View {
        VStack(spacing: ForgeSpacing.s4) {
            NavigationLink {
                PhysiqueAssessmentHistoryView()
            } label: {
                ForgeCard {
                    HStack {
                        ForgeSectionHeader(
                            title: "Assessment history",
                            subtitle: "Past snapshots and changes"
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(ForgeTypography.caption.weight(.semibold))
                            .foregroundStyle(ForgeColors.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("physique.history")

            PhysiqueAssessmentReportContent(
                assessment: assessment,
                sinceLastDiff: environment.sinceLastPhysiqueDiff(photos: photos)
            )

            PhysiqueIllustrationSection(
                assessment: assessment,
                photos: photos
            )

            if !hasBackPhoto || !hasSidePhoto {
                anglesUpsellCard
            }

            ForgeButton(
                title: "Reassess",
                style: .secondary,
                isLoading: isAssessing,
                accessibilityIdentifier: "physique.reassess"
            ) {
                Task { await runAssessment() }
            }
        }
    }

    private var anglesUpsellCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                Text("Add back and side photos for better results.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
                if !hasBackPhoto {
                    ForgeButton(title: "Add Back Photo", style: .secondary) { presentAddPhoto(for: .back) }
                }
                if !hasSidePhoto {
                    ForgeButton(title: "Add Side Photo", style: .secondary) { presentAddPhoto(for: .side) }
                }
            }
        }
        .accessibilityIdentifier("physique.anglesUpsell")
    }

    @ViewBuilder
    private func photoActionButtons(missingAngles: [PhysiquePhotoAngle]) -> some View {
        if missingAngles.contains(.front) || !hasFrontPhoto {
            ForgeButton(title: "Add Front Photo", style: .secondary, isLoading: isImporting) {
                presentAddPhoto(for: .front)
            }
        }
        if missingAngles.contains(.back) || !hasBackPhoto {
            ForgeButton(title: "Add Back Photo", style: .secondary, isLoading: isImporting) {
                presentAddPhoto(for: .back)
            }
        }
        if !hasSidePhoto {
            ForgeButton(title: "Add Side Photo", style: .secondary, isLoading: isImporting) {
                presentAddPhoto(for: .side)
            }
        }
    }

    // MARK: - Photo helpers

    private var hasFrontPhoto: Bool {
        photos.contains { [.frontRelaxed, .frontFlexed].contains($0.poseType) }
    }

    private var hasBackPhoto: Bool {
        photos.contains { [.backRelaxed, .backFlexed].contains($0.poseType) }
    }

    private var hasSidePhoto: Bool {
        photos.contains { [.sideRelaxed, .sideFlexed].contains($0.poseType) }
    }

    private func emptyMessage(missingAngles: [PhysiquePhotoAngle]) -> String {
        _ = missingAngles
        return "Add a front photo to get a focus plan."
    }

    private func presentAddPhoto(for angle: PhysiquePhotoAngle) {
        guard environment.userProfile?.id != nil else {
            importError = "Complete onboarding before adding progress photos."
            return
        }
        importError = nil
        addPhotoPose = pose(for: angle)
        showAddPhoto = true
    }

    private func pose(for angle: PhysiquePhotoAngle) -> BodyPhotoPoseType {
        switch angle {
        case .front: .frontRelaxed
        case .back: .backRelaxed
        case .side: .sideRelaxed
        }
    }

    private func importPhotoData(_ data: Data) async {
        guard let userId = environment.userProfile?.id else {
            importError = "Complete onboarding before adding progress photos."
            return
        }

        isImporting = true
        importError = nil
        defer { isImporting = false }

        do {
            _ = try await environment.importBodyPhoto(
                imageData: data,
                userId: userId,
                pose: addPhotoPose,
                weightKg: environment.userProfile?.weightKg
            )
            await refresh()
        } catch BodyPhotoImportError.invalidImage {
            importError = "Could not import photo. Try a different image."
        } catch {
            importError = "Could not save photo. Try again."
        }
    }

    private func runAssessment() async {
        isAssessing = true
        defer { isAssessing = false }
        _ = await environment.assessPhysique(photos: photos)
        hasStalePhotos = await environment.hasStalePhysiquePhotos(photos: photos)
    }

    private func refresh() async {
        photos = await environment.fetchBodyPhotos()
        gateResult = PhysiquePhotoGate.evaluate(photos: photos)
        hasStalePhotos = await environment.hasStalePhysiquePhotos(photos: photos)
        await environment.loadActivePhysiqueAssessment()
    }
}

#Preview {
    PhysiqueView()
        .environment(AppEnvironment())
        .environment(AppRouter())
}
