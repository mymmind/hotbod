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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let latest = photos.sorted(by: { $0.date > $1.date }).first {
                        latestPhotoCard(latest)
                    }
                    poseSelector
                    ForgeButton(title: "Add Photo", style: .accent) { showPicker = true }
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
            .task { await load() }
        }
    }

    private func latestPhotoCard(_ photo: BodyProgressPhoto) -> some View {
        ForgeCard {
            ForgeSectionHeader(title: "Latest", subtitle: photo.poseType.displayName)
            if let image = loadImage(path: photo.localImagePath) {
                image.resizable().scaledToFit().frame(maxHeight: 280)
            }
            if let analysis = photo.analysis {
                Text("Pose: \(Int(analysis.poseConfidence * 100))% · Lighting: \(Int(analysis.lightingScore * 100))%")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
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

    private var timelineSection: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Timeline")
            if photos.isEmpty {
                Text("No photos yet. Import your first progress photo.")
                    .foregroundStyle(ForgeColors.muted)
            } else {
                ForEach(photos.sorted(by: { $0.date > $1.date })) { photo in
                    HStack {
                        if let image = loadImage(path: photo.localImagePath) {
                            image.resizable().scaledToFill().frame(width: 48, height: 64).clipped()
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

    private var comparisonSection: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Comparison")
            if let latest = photos.sorted(by: { $0.date > $1.date }).first,
               let analysis = latest.analysis {
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
                if photos.count >= 2 {
                    ForgeButton(title: "Compare Latest Two", style: .secondary) {
                        Task { await compareLatestTwo() }
                    }
                }
            } else {
                Text("Add a second photo with the same pose for visual trend comparison.")
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
            }
            Text(label).font(ForgeTypography.caption)
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    private func compareLatestTwo() async {
        let sorted = photos.sorted(by: { $0.date > $1.date })
        guard sorted.count >= 2 else { return }
        let latest = sorted[0]
        let previous = sorted[1]
        let analysis = try? await environment.bodyPhotoAnalyzer.analyze(photo: latest, previous: previous)
        let summary = analysis?.comparisonSummary ?? "Comparison unavailable."
        activeComparison = BodyPhotoComparisonResult(before: previous, after: latest, summary: summary)
    }

    private func loadImage(path: String) -> Image? {
        guard let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let userId = environment.userProfile?.id,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        let dir = environment.bodyPhotosDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        let path = dir.appendingPathComponent(filename).path
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? jpeg.write(to: URL(fileURLWithPath: path))

        var photo = BodyProgressPhoto(
            id: UUID(), userId: userId, date: Date(), poseType: selectedPose,
            localImagePath: path, weightKg: environment.userProfile?.weightKg
        )
        photo.analysis = try? await environment.bodyPhotoAnalyzer.analyze(photo: photo, previous: photos.last)
        try? await environment.saveBodyPhoto(photo, fileData: jpeg)
        await load()
    }

    private func load() async {
        photos = await environment.fetchBodyPhotos()
    }
}
