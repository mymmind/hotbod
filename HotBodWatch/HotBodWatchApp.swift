import SwiftUI
import WatchKit

@main
struct HotBodWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
        }
    }
}

struct WatchWorkoutView: View {
    @State private var snapshot = WatchSessionSnapshot.empty
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.title)
                    .font(.headline)
                Text(snapshot.exerciseName)
                    .font(.title3.bold())
                if snapshot.totalSets > 0 {
                    Text("Set \(min(snapshot.setIndex + 1, snapshot.totalSets)) / \(snapshot.totalSets)")
                        .font(.caption)
                    if let weight = snapshot.targetWeightKg {
                        Text("\(Int(weight)) kg")
                            .font(.title2.monospacedDigit())
                    }
                    if snapshot.isMaxEffort {
                        Text("AMRAP")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(snapshot.targetRepsMin)–\(snapshot.targetRepsMax) reps")
                            .font(.caption)
                    }
                } else {
                    Text("Start a workout on iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if snapshot.isResting, let rest = snapshot.restSecondsRemaining {
                    Text("Rest \(rest)s")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.green)
                }

                if snapshot.totalSets > 0 {
                    Button("Complete Set") {
                        AppGroupSessionStore.writePendingCommand(
                            WatchPendingCommand(action: .completeSet, issuedAt: Date())
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    if snapshot.isResting {
                        Button("Skip Rest") {
                            AppGroupSessionStore.writePendingCommand(
                                WatchPendingCommand(action: .skipRest, issuedAt: Date())
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(timer) { _ in
            let updated = AppGroupSessionStore.readSnapshot()
            playRestEndHapticIfNeeded(previous: snapshot, updated: updated)
            snapshot = updated
        }
        .onAppear {
            snapshot = AppGroupSessionStore.readSnapshot()
        }
    }

    private func playRestEndHapticIfNeeded(previous: WatchSessionSnapshot, updated: WatchSessionSnapshot) {
        guard previous.isResting,
              let previousRest = previous.restSecondsRemaining,
              previousRest > 0 else { return }

        let restEnded = !updated.isResting || (updated.restSecondsRemaining ?? 0) == 0
        guard restEnded else { return }

        WKInterfaceDevice.current().play(.notification)
    }
}

#Preview {
    WatchWorkoutView()
}
