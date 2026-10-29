import AVFoundation
import Observation
import SwiftUI
import UIKit

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
                demoPlayback(for: playbackURL)
            }

            if isLoading, playbackURL == nil {
                demoPlaceholder(showSpinner: true)
                    .transition(.opacity)
            } else if playbackURL == nil, !isLoading {
                demoPlaceholder(showSpinner: false)
                    .transition(.opacity)
            }
        }
        .frame(height: showsFilePlayer ? playerHeight : nil)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(ForgeColors.foreground.opacity(style == .fullBleed ? 0.06 : 0))
        .animation(ForgeMotion.exercise, value: playbackURL)
    }

    private var showsFilePlayer: Bool {
        guard let playbackURL else { return true }
        return YouTubeVideoID(url: playbackURL) == nil
    }

    @ViewBuilder
    private func demoPlayback(for url: URL) -> some View {
        if let videoID = YouTubeVideoID(url: url) {
            YouTubeEmbedPlayer(videoID: videoID)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .accessibilityLabel("Exercise demonstration")
        } else {
            LoopingVideoPlayer(url: url)
                .id(url)
                .frame(height: playerHeight)
        }
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
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40))
                    }
                    Text(showSpinner ? "Demo video" : "No demo clip")
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

        if UITestConfiguration.isUITesting {
            withAnimation(ForgeMotion.exercise) {
                playbackURL = nil
                isLoading = false
            }
            return
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
        ZStack {
            DemoPlayerLayer(player: model.player)
            if model.failed {
                Text("Demo unavailable")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
        .onAppear { model.play() }
        .onDisappear { model.pause() }
    }
}

/// `VideoPlayer` keeps the transport paused until a tap, so short bundled clips never start.
/// An `AVPlayerLayer` starts as soon as the layer is in the hierarchy.
private struct DemoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> DemoPlayerHostView {
        let view = DemoPlayerHostView()
        view.attach(player)
        return view
    }

    func updateUIView(_ uiView: DemoPlayerHostView, context: Context) {
        uiView.attach(player)
    }
}

private final class DemoPlayerHostView: UIView {
    private let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func attach(_ player: AVPlayer) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }
}

@MainActor
@Observable
private final class LoopingPlayerModel {
    let player: AVPlayer
    private(set) var failed = false
    private var wantsPlayback = false
    private nonisolated(unsafe) var endObserver: NSObjectProtocol?
    private nonisolated(unsafe) var interruptionObserver: NSObjectProtocol?
    private nonisolated(unsafe) var duckObserver: NSObjectProtocol?
    private nonisolated(unsafe) var statusObserver: NSKeyValueObservation?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsPlayback else { return }
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    Task { @MainActor in
                        guard let self, finished, self.wantsPlayback else { return }
                        self.playMixed()
                    }
                }
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            Task { @MainActor in
                guard type == .ended else { return }
                self?.resumeIfNeeded()
            }
        }
        duckObserver = NotificationCenter.default.addObserver(
            forName: .forgeAudioDuckReleased,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeIfNeeded()
            }
        }
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor in
                    self?.failed = true
                }
                return
            }
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                self?.failed = false
                self?.resumeIfNeeded()
            }
        }
    }

    func play() {
        wantsPlayback = true
        playMixed()
    }

    func pause() {
        wantsPlayback = false
        player.pause()
    }

    private func resumeIfNeeded() {
        guard wantsPlayback, !failed else { return }
        playMixed()
    }

    /// Muted clips still activate the shared session. Leave a rest-chime duck alone, and otherwise mix.
    private func playMixed() {
        let session = AVAudioSession.sharedInstance()
        let ducking = session.category == .playback && session.categoryOptions.contains(.duckOthers)
        if !ducking {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        player.play()
    }

    nonisolated deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let duckObserver {
            NotificationCenter.default.removeObserver(duckObserver)
        }
        statusObserver?.invalidate()
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
        Group {
            if let videoID = selectedYouTubeID {
                youtubeHero(videoID)
            } else {
                fileHero
            }
        }
        .background(ForgeColors.foreground.opacity(0.08))
        .task(id: exerciseId) {
            await loadVideos()
        }
    }

    private var selectedYouTubeID: YouTubeVideoID? {
        guard let video = selectedVideo,
              let url = ExerciseMediaResolver.resolvePlaybackURL(for: video) else { return nil }
        return YouTubeVideoID(url: url)
    }

    private func youtubeHero(_ videoID: YouTubeVideoID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            backButton
                .padding(.leading, ForgeSpacing.s4)
                .padding(.vertical, ForgeSpacing.s3)
            YouTubeEmbedPlayer(videoID: videoID)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .accessibilityLabel("Exercise demonstration")
        }
    }

    private var fileHero: some View {
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

            backButton
                .padding(.leading, ForgeSpacing.s4)
                .padding(.top, ForgeSpacing.s3)

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
    }

    private var backButton: some View {
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
        .accessibilityLabel("Back")
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let video = selectedVideo,
           let url = ExerciseMediaResolver.resolvePlaybackURL(for: video),
           YouTubeVideoID(url: url) == nil {
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
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: ForgeIcons.play))
                        .foregroundStyle(ForgeColors.textSecondary)
                    Text("No demo clip")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
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

        if UITestConfiguration.isUITesting {
            isLoading = false
            return
        }

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
