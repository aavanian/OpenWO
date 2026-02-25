import SwiftUI
import Combine

struct TimerView: View {
    let label: String
    var stopped: Bool = false

    @StateObject private var state = TimerState()

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)

            if state.totalDuration > 0 {
                Text(formatTime(state.displaySeconds))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }

            Button {
                if state.isRunning {
                    state.pause()
                } else {
                    if state.totalDuration == 0 {
                        state.totalDuration = parseSeconds(from: label)
                    }
                    state.start()
                }
            } label: {
                Image(systemName: state.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .onChange(of: stopped) { newValue in
            if newValue && state.isRunning {
                state.pause()
            }
        }
    }

    private func parseSeconds(from text: String) -> Int {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
        guard let first = numbers.first else { return 60 }
        if text.lowercased().contains("min") {
            return first * 60
        }
        return first
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private final class TimerState: ObservableObject {
    @Published var isRunning = false
    @Published var totalDuration: Int = 0

    private var startDate: Date?
    private var elapsedBeforePause: TimeInterval = 0
    private var cancellable: AnyCancellable?

    var displaySeconds: Int {
        max(totalDuration - Int(currentElapsed), 0)
    }

    private var currentElapsed: TimeInterval {
        if let start = startDate {
            return elapsedBeforePause + Date().timeIntervalSince(start)
        }
        return elapsedBeforePause
    }

    func start() {
        startDate = Date()
        isRunning = true

        cancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
                if self.displaySeconds <= 0 {
                    self.finish()
                }
            }
    }

    func pause() {
        elapsedBeforePause = currentElapsed
        startDate = nil
        isRunning = false
        cancellable?.cancel()
        cancellable = nil
    }

    private func finish() {
        pause()
        Haptics.medium()
    }
}
