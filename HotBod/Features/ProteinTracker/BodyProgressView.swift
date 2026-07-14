import SwiftUI
import PhotosUI
import UIKit

struct BodyProgressView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var photos: [BodyProgressPhoto] = []
    @State private var showPicker = false
    @State private var selectedPose: BodyPhotoPoseType = .frontRelaxed
    @State private var pickerItem: PhotosPickerItem?
    @State private var activeComparison: BodyPhotoComparisonResult?
    @State private var isImporting = false
    @State private var importError: String?

    private var sortedPhotos: [BodyProgressPhoto] {
        BodyProgressPhoto.sortedByDateDescending(photos)
    }

    private var trackingEnabled: Bool {
        environment.isPhotoTrackingEnabled
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if trackingEnabled, photos.isEmpty {
                    trackingPromptBanner
                }
                if let latest = sortedPhotos.first {
                    latestPhotoCard(latest)
                }
                poseSelector
                if let importError {
                    Text(importError)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.destructive)
                }
                ForgeButton(
                    title: "Add Photo",
                    style: .accent,
                    isLoading: isImporting,
                    accessibilityIdentifier: "bodyProgress.addPhoto"
                ) {
                    guard environment.userProfile?.id != nil else {
                        importError = "Complete onboarding before adding progress photos."
                        return
                    }
                    importError = nil
                    showPicker = true
                }
                timelineSection
                comparisonSection
            }
            .padding()
        }
        .background(ForgeColors.background)
        .navigationTitle("Body Progress")
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            Task { await importPhoto(item) }
        }
        .task(id: environment.bodyPhotoRevision) {
            await load()
        }
    }

    private var trackingPromptBanner: some View {
        ForgeCard {
            Text("Photo tracking is on. Add your first front, side, or back photo to start a visual timeline.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private func latestPhotoCard(_ photo: BodyProgressPhoto) -> some View {
        ForgeCard {
            ForgeSectionHeader(title: "Latest", subtitle: photo.poseType.displayName)
            if let image = loadImage(path: photo.localImagePath) {
                image.resizable().scaledToFit().frame(maxHeight: 280)
            } else {
                missingImagePlaceholder
            }
            if let analysis = photo.analysis {
                Text("Pose: \(Int(analysis.poseConfidence * 100))% · Lighting: \(Int(analysis.lightingScore * 100))%")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    private var missingImagePlaceholder: some View {
        Rectangle()
            .fill(ForgeColors.muted.opacity(0.2))
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .overlay {
                Text("Photo file unavailable. Re-import or sync again.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                    .multilineTextAlignment(.center)
                    .padding()
            }
    }

    private var poseSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(BodyPhotoPoseType.allCases) { pose in
                    SelectableChip(title: pose.displayName, isSelected: selectedPose == pose) {
                        selectedPose = pose
                        activeComparison = nil
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Timeline")
            if photos.isEmpty {
                Text(emptyTimelineMessage)
                    .foregroundStyle(ForgeColors.muted)
            } else {
                ForEach(sortedPhotos) { photo in
                    HStack {
                        if let image = loadImage(path: photo.localImagePath) {
                            image.resizable().scaledToFill().frame(width: 48, height: 64).clipped()
                        } else {
                            Rectangle()
                                .fill(ForgeColors.muted.opacity(0.25))
                                .frame(width: 48, height: 64)
                        }
                        VStack(alignment: .leading) {
                            Text(photo.poseType.displayName).font(ForgeTypography.heading)
                            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                .font(ForgeTypography.caption).foregroundStyle(ForgeColors.muted)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var emptyTimelineMessage: String {
        if trackingEnabled {
            return "No photos yet. Add your first progress photo to start tracking."
        }
        return "No photos yet. Import your first progress photo."
    }

    private var comparisonSection: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Comparison", subtitle: selectedPose.displayName)
            if let latestForPose = BodyProgressPhoto.latest(matching: selectedPose, in: photos) {
                if let analysis = latestForPose.analysis {
                    if let summary = analysis.comparisonSummary {
                        Text(summary)
                            .font(ForgeTypography.body)
                    }
                    if let ratio = analysis.shoulderWaistRatio {
                        Text(String(format: "Shoulder-to-waist visual ratio: %.2f", ratio))
                            .font(ForgeTypography.monoMetric)
                    }
                    ForEach(analysis.limitations, id: \.self) { note in
                        Text(note)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                }
                if BodyProgressPhoto.latestPair(matching: selectedPose, in: photos) != nil {
                    ForgeButton(title: "Compare Latest Two", style: .secondary) {
                        Task { await compareLatestForSelectedPose() }
                    }
                } else if latestForPose.analysis == nil {
                    Text("Analysis pending for this pose. Add another matching photo or tap compare.")
                        .foregroundStyle(ForgeColors.muted)
                }
            } else {
                Text("Add a photo for this pose to start visual trend comparison.")
                    .foregroundStyle(ForgeColors.muted)
            }
            if let comparison = activeComparison {
                comparisonResultCard(comparison)
            }
        }
    }

    private struct BodyPhotoComparisonResult {
        let before: BodyProgressPhoto
        let after: BodyProgressPhoto
        let summary: String
    }

    private func comparisonResultCard(_ comparison: BodyPhotoComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(comparison.summary)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            HStack(spacing: 8) {
                comparisonThumbnail(comparison.before, label: "Earlier")
                comparisonThumbnail(comparison.after, label: "Latest")
            }
        }
        .padding(.top, 8)
    }

    private func comparisonThumbnail(_ photo: BodyProgressPhoto, label: String) -> some View {
        VStack(spacing: 4) {
            if let image = loadImage(path: photo.localImagePath) {
                image.resizable().scaledToFill().frame(width: 120, height: 160).clipped()
            } else {
                Rectangle()
                    .fill(ForgeColors.muted.opacity(0.25))
                    .frame(width: 120, height: 160)
            }
            Text(label).font(ForgeTypography.caption)
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private func compareLatestForSelectedPose() async {
        guard let pair = BodyProgressPhoto.latestPair(matching: selectedPose, in: photos) else { return }
        let analysis = try? await environment.bodyPhotoAnalyzer.analyze(photo: pair.latest, previous: pair.previous)
        let summary = analysis?.comparisonSummary ?? "Comparison unavailable."
        if let analysis {
            var updatedLatest = pair.latest
            updatedLatest.analysis = analysis
            try? await environment.saveBodyPhoto(updatedLatest, fileData: nil)
        }
        activeComparison = BodyPhotoComparisonResult(before: pair.previous, after: pair.latest, summary: summary)
        await load()
    }

    private func loadImage(path: String) -> Image? {
        guard BodyPhotoImageProcessor.fileExists(at: path),
              let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let userId = environment.userProfile?.id else {
            importError = "Complete onboarding before adding progress photos."
            return
        }

        isImporting = true
        importError = nil
        defer {
            isImporting = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "Could not read the selected photo."
                return
            }
            _ = try await environment.importBodyPhoto(
                imageData: data,
                userId: userId,
                pose: selectedPose,
                weightKg: environment.userProfile?.weightKg
            )
            activeComparison = nil
            await load()
        } catch BodyPhotoImportError.invalidImage {
            importError = "Could not import photo. Try a different image."
        } catch {
            importError = "Could not save photo. Try again."
        }
    }

    private func load() async {
        photos = await environment.fetchBodyPhotos()
    }
}
