import SwiftUI

struct ForgeProgressBar: View {
    let progress: Double
    var inverted: Bool = false
    var fill: Color? = nil
    var height: CGFloat = 4

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(trackColor)
                Rectangle()
                    .fill(fillColor)
                    .frame(width: geometry.size.width * animatedProgress)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(ForgeMotion.standard.delay(0.2)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(ForgeMotion.standard) {
                animatedProgress = clampedProgress
            }
        }
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var trackColor: Color {
        inverted ? ForgeColors.surface.opacity(0.25) : ForgeColors.border
    }

    private var fillColor: Color {
        if let fill { return fill }
        return inverted ? ForgeColors.surface : ForgeColors.foreground
    }
}

#Preview {
    VStack(spacing: 16) {
        ForgeProgressBar(progress: 0.72, fill: ForgeColors.accent)
        ForgeProgressBar(progress: 0.45, inverted: true, fill: ForgeColors.accentBlue)
    }
    .padding()
    .background(ForgeColors.surfaceInverse)
}
