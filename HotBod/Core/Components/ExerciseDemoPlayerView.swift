import AVKit
import SwiftUI

struct ExerciseDemoPlayerView: View {
    let exerciseId: String
    var mediaProvider: (any ExerciseMediaProvider)?
    var style: ExerciseDemoPlayerStyle = .card

    @Environment(\.isPreview) private var isPreview
    @State private var playbackURL: URL?
    @State private var isLoading = true

    private var playerHeight: CGFloat {
        style == .fullBleed ? 220 : 180
    }

    var body: some View {
        Group {
            if style == .card {
                ForgeCard { playerContent }
            } else {
                playerContent
            }
        }
        .task(id: exerciseId) {
            await loadVideo()
        }
    }

    private var playerContent: some View {
        ZStack {
            if let playbackURL {
                LoopingVideoPlayer(url: playbackURL)
                    .frame(height: playerHeight)
                    .transition(.opacity)
            }

            if isLoading, playbackURL == nil {
                demoPlaceholder(showSpinner: true)
                    .transition(.opacity)
            } else if playbackURL == nil, !isLoading {
                demoPlaceholder(showSpinner: false)
                    .transition(.opacity)
            }
        }
        .frame(height: playerHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(ForgeColors.foreground.opacity(style == .fullBleed ? 0.06 : 0))
        .animation(ForgeMotion.exercise, value: playbackURL)
    }

    private func demoPlaceholder(showSpinner: Bool) -> some View {
        Rectangle()
            .fill(ForgeColors.foreground.opacity(0.08))
            .frame(height: playerHeight)
            .overlay {
                VStack(spacing: 8) {
                    if showSpinner {
                        ProgressView()
                    } else {
                        Image(systemName: "play.circle")
                            .font(.system(size: 40))
                    }
                    Text("Demo video")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
    }

    private func loadVideo() async {
        let isFirstLoad = playbackURL == nil
        if isFirstLoad {
            isLoading = true
        }

        let resolved: URL?
        if isPreview {
            resolved = ExerciseMediaResolver.bundledFallback(for: exerciseId)
                .flatMap { ExerciseMediaResolver.resolvePlaybackURL(for: $0) }
        } else {
            let provider = mediaProvider ?? LocalExerciseMediaProvider()
            let videos = (try? await provider.demoVideos(for: exerciseId)) ?? []
            resolved = videos.compactMap { ExerciseMediaResolver.resolvePlaybackURL(for: $0) }.first
        }

        withAnimation(ForgeMotion.exercise) {
            playbackURL = resolved
            isLoading = false
        }
    }
}

enum ExerciseDemoPlayerStyle {
    case card
    case fullBleed
}

private struct LoopingVideoPlayer: View {
    let url: URL
    @State private var model: LoopingPlayerModel

    init(url: URL) {
        self.url = url
        _model = State(initialValue: LoopingPlayerModel(url: url))
    }

    var body: some View {
        VideoPlayer(player: model.player)
            .onAppear { model.play() }
            .onDisappear { model.pause() }
    }
}

@MainActor
private final class LoopingPlayerModel {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        player.isMuted = true
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}

private struct PreviewEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var isPreview: Bool {
        get { self[PreviewEnvironmentKey.self] }
        set { self[PreviewEnvironmentKey.self] = newValue }
    }
}

// MARK: - Detail hero (Fitbod-style full-bleed media)

struct ExerciseDetailMediaHero: View {
    let exerciseId: String
    var mediaProvider: (any ExerciseMediaProvider)?
    var onBack: () -> Void

    @Environment(\.isPreview) private var isPreview
    @State private var videos: [ExerciseDemoVideo] = []
    @State private var selectedVideoId: String?
    @State private var isLoading = true

    private var selectedVideo: ExerciseDemoVideo? {
        if let selectedVideoId {
            return videos.first { $0.id == selectedVideoId }
        }
        return videos.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            mediaContent
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .clipped()

            if videos.count > 1 {
                VStack(spacing: 8) {
                    ForEach(videos) { video in
                        angleThumbnail(for: video)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 60)
            }

            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ForgeColors.backgroundPrimary)
                    .frame(width: 36, height: 36)
                    .background(ForgeColors.textPrimary.opacity(0.55))
                    .clipShape(Circle())
            }
            .frame(width: ForgeTarget.min, height: ForgeTarget.min)
            .contentShape(Rectangle())
            .padding(.leading, ForgeSpacing.s4)
            .padding(.top, ForgeSpacing.s3)
            .accessibilityLabel("Back")

            if selectedVideo != nil {
                Text("1.0×")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ForgeColors.foreground.opacity(0.55))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
            }
        }
        .background(ForgeColors.foreground.opacity(0.08))
        .task(id: exerciseId) {
            await loadVideos()
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let video = selectedVideo,
           let url = ExerciseMediaResolver.resolvePlaybackURL(for: video) {
            LoopingVideoPlayer(url: url)
                .id(video.id)
        } else if isLoading {
            heroPlaceholder(showSpinner: true)
        } else {
            heroPlaceholder(showSpinner: false)
        }
    }

    private func angleThumbnail(for video: ExerciseDemoVideo) -> some View {
        let isSelected = video.id == (selectedVideo?.id ?? "")
        return Button {
            selectedVideoId = video.id
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(ForgeColors.foreground.opacity(0.25))
                .frame(width: 52, height: 52)
                .overlay {
                    Text(angleLabel(video.angle))
                        .font(ForgeTypography.tabLabel.weight(.bold))
                        .foregroundStyle(ForgeColors.backgroundPrimary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(ForgeColors.background, lineWidth: isSelected ? 2.5 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(angleLabel(video.angle)) angle")
    }

    private func heroPlaceholder(showSpinner: Bool) -> some View {
        ZStack {
            ForgeColors.foreground.opacity(0.06)
            VStack(spacing: 8) {
                if showSpinner {
                    ProgressView()
                } else {
                    Image(systemName: "play.circle")
                        .font(.system(size: ForgeIcons.play))
                        .foregroundStyle(ForgeColors.textSecondary)
                }
            }
        }
    }

    private func angleLabel(_ angle: DemoAngle) -> String {
        switch angle {
        case .front: "FRONT"
        case .side: "SIDE"
        case .fortyFive: "45°"
        case .closeUp: "CLOSE"
        }
    }

    private func loadVideos() async {
        isLoading = true
        videos = []

        if isPreview {
            if let fallback = ExerciseMediaResolver.bundledFallback(for: exerciseId) {
                videos = [fallback]
            }
            selectedVideoId = videos.first?.id
            isLoading = false
            return
        }

        let provider = mediaProvider ?? LocalExerciseMediaProvider()
        let fetched = (try? await provider.demoVideos(for: exerciseId)) ?? []
        videos = fetched.filter { ExerciseMediaResolver.resolvePlaybackURL(for: $0) != nil }
        selectedVideoId = videos.first?.id
        isLoading = false
    }
}

#Preview {
    ExerciseDemoPlayerView(exerciseId: "bench_press")
        .environment(\.isPreview, true)
        .padding()
        .background(ForgeColors.background)
}

#Preview("Detail Hero") {
    ExerciseDetailMediaHero(exerciseId: "bench_press", onBack: {})
        .environment(\.isPreview, true)
}
