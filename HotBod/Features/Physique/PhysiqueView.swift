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
            emptySection(missingAngles: [.front, .back])
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
                Text("Front and back photos are ready.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)

                if !hasSidePhoto {
                    ForgeButton(title: "Add side for higher confidence", style: .secondary) {
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
        let resolvedDirections = PhysiqueDirectionResolve.resolved(
            matches: assessment.physiqueDirections,
            catalog: PhysiqueArchetypeCatalogLoader.indexedById()
        )

        return VStack(spacing: ForgeSpacing.s4) {
            ForgeCard {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    ForgeSectionHeader(
                        title: "Build Summary",
                        subtitle: assessment.physique.overallArchetype
                    )
                    summaryRow("Frame", assessment.physique.frameSize)
                    summaryRow("Shoulder to waist", assessment.physique.shoulderToWaist)
                    summaryRow("Muscularity", assessment.physique.muscularity)
                    summaryRow("Leanness", assessment.physique.leanness)
                }
            }

            if let diff = environment.sinceLastPhysiqueDiff(photos: photos) {
                sinceLastCard(diff)
            }

            ForgeCard {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    ForgeSectionHeader(title: "Development Priorities", subtitle: "Ranked focus areas")
                    ForEach(assessment.developmentPriorities, id: \.muscle) { priority in
                        VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                            Text(priority.muscle.displayName)
                                .font(ForgeTypography.body.weight(.semibold))
                            Text(priority.reason)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("physique.priority.\(priority.muscle.rawValue)")
                        if priority.muscle != assessment.developmentPriorities.last?.muscle {
                            Divider()
                        }
                    }
                }
            }

            if !resolvedDirections.isEmpty {
                physiqueDirectionsSection(resolvedDirections)
            }

            ForgeCard {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    ForgeSectionHeader(title: "Why today’s training", subtitle: nil)
                    Text(assessment.whyTodaySummary)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.muted)
                        .lineLimit(5)
                    if !assessment.trainingBias.rationale.isEmpty {
                        Text(assessment.trainingBias.rationale)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                }
            }

            if !hasSidePhoto {
                ForgeButton(title: "Add side for higher confidence", style: .secondary) {
                    presentAddPhoto(for: .side)
                }
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

    private func sinceLastCard(_ diff: PhysiqueAssessmentDiff) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Since last assessment",
                    subtitle: dateRangeSubtitle(from: diff.previousDate, to: diff.currentDate)
                )
                ForEach(diff.summaryLines, id: \.self) { line in
                    Text(line)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !diff.visionTrends.isEmpty {
                    Text("Visual trend")
                        .font(ForgeTypography.caption.weight(.semibold))
                        .foregroundStyle(ForgeColors.muted)
                    ForEach(diff.visionTrends, id: \.self) { trend in
                        Text(trend)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .accessibilityIdentifier("physique.sinceLast")
        }
    }

    private func dateRangeSubtitle(from previousDate: Date, to currentDate: Date) -> String {
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return "\(previousDate.formatted(format)) → \(currentDate.formatted(format))"
    }

    private func physiqueDirectionsSection(
        _ resolvedDirections: [(match: PhysiqueArchetypeMatch, entry: PhysiqueArchetypeCatalogEntry)]
    ) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Physique directions",
                    subtitle: "Reference directions for proportions and silhouette — not a prediction."
                )

                ForEach(resolvedDirections, id: \.match.archetypeId) { resolved in
                    VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                        Text(resolved.entry.genericLabel)
                            .font(ForgeTypography.body.weight(.semibold))
                        if let referenceLine = PhysiqueDirectionCopy.referenceLine(for: resolved.entry) {
                            Text(referenceLine)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                        Text(resolved.match.similarityDimension)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("physique.direction.\(resolved.match.archetypeId)")
                    if resolved.match.archetypeId != resolvedDirections.last?.match.archetypeId {
                        Divider()
                    }
                }

                Text(
                    "These are physique directions, not identity matches. "
                        + "Bone structure, insertions, and training response differ."
                )
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
            .accessibilityIdentifier("physique.directions")
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            Spacer()
            Text(value)
                .font(ForgeTypography.body)
        }
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
        if hasFrontPhoto && hasBackPhoto && !hasSidePhoto {
            ForgeButton(title: "Add side for higher confidence", style: .secondary, isLoading: isImporting) {
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
        if missingAngles == [.back] {
            return "Add a back photo to unlock a full assessment."
        }
        return "Add front and back photos to get a focus plan."
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
