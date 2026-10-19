import SwiftUI
import WatchConnectivity
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
    @State private var lastRestRemaining: Int?
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let displayed = snapshot.restRemaining(at: context.date)
            content(at: context.date)
                .onChange(of: displayed) { _, newValue in
                    noteDisplayedRest(newValue)
                }
        }
        .onReceive(timer) { _ in
            snapshot = AppGroupSessionStore.readSnapshot()
        }
        .onAppear {
            WatchCommandRelay.activate()
            snapshot = AppGroupSessionStore.readSnapshot()
            lastRestRemaining = snapshot.restRemaining(at: Date())
        }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        switch snapshot.resolvedPhase {
        case .ready:
            readyContent
        case .active:
            activeContent(at: date)
        case .idle:
            idleContent
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HotBod")
                .font(.headline)
            Text("Start a workout on iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.title)
                .font(.headline)
            Text(snapshot.exerciseName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Start Workout") {
                WatchCommandRelay.send(.startWorkout)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activeContent(at date: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.exerciseName)
                    .font(.headline)
                if snapshot.totalSets > 0 {
                    Text("Set \(min(snapshot.setIndex + 1, snapshot.totalSets)) / \(snapshot.totalSets)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                stepperRow(
                    value: loadText,
                    minus: .decreaseWeight,
                    plus: .increaseWeight
                )

                stepperRow(
                    value: "\(snapshot.displaySecondaryValue) \(snapshot.displaySecondaryLabel)",
                    minus: .decreaseReps,
                    plus: .increaseReps
                )

                if let next = snapshot.nextSummary {
                    Text(next)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let rest = snapshot.restRemaining(at: date) {
                    Text(restText(rest))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.green)
                }

                Button("Mark Set Done") {
                    WatchCommandRelay.send(.completeSet)
                }
                .buttonStyle(.borderedProminent)

                if snapshot.isResting {
                    Button("Skip Rest") {
                        WatchCommandRelay.send(.skipRest)
                    }
                }

                Button("End Workout") {
                    WatchCommandRelay.send(.endWorkout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loadText: String {
        guard let weight = snapshot.displayWeightKg else { return "— \(snapshot.resolvedLoadUnit)" }
        let number = weight.rounded() == weight ? String(Int(weight)) : String(format: "%.1f", weight)
        return snapshot.resolvedLoadUnit == "lvl" ? "\(number) lvl" : "\(number) kg"
    }

    private func restText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return String(format: "Rest %d:%02d", minutes, remainder)
        }
        return "Rest \(seconds)s"
    }

    private func stepperRow(value: String, minus: WatchSessionCommand, plus: WatchSessionCommand) -> some View {
        HStack {
            Button("−") { WatchCommandRelay.send(minus) }
                .buttonStyle(.bordered)
            Text(value)
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity)
            Button("+") { WatchCommandRelay.send(plus) }
                .buttonStyle(.bordered)
        }
    }

    private func noteDisplayedRest(_ displayed: Int?) {
        if WatchRestHaptic.shouldFire(lastDisplayedRemaining: lastRestRemaining, displayedRemaining: displayed) {
            WKInterfaceDevice.current().play(.notification)
        }
        lastRestRemaining = displayed
    }
}

enum WatchCommandRelay {
    static func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = WatchSessionRelayDelegate.shared
        }
        if session.activationState != .activated {
            session.activate()
        }
    }

    static func send(_ action: WatchSessionCommand) {
        AppGroupSessionStore.issuePendingCommand(action)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        activate()
        let payload = ["drain": true]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }
}

final class WatchSessionRelayDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSessionRelayDelegate()

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}

#Preview {
    WatchWorkoutView()
}
