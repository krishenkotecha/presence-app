import Foundation

@MainActor
final class RecordingSimulator: ObservableObject {
    @Published private(set) var visibleTranscript: [TranscriptBeat] = []
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isRecording = false
    @Published private(set) var conversationPulse: Double = 0.68

    let activeSession: ActiveConversation

    private var timerTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var pulseTask: Task<Void, Never>?

    init(activeSession: ActiveConversation) {
        self.activeSession = activeSession
    }

    deinit {
        timerTask?.cancel()
        transcriptTask?.cancel()
        pulseTask?.cancel()
    }

    func start() {
        guard !isRecording else { return }

        isRecording = true
        elapsedSeconds = 0
        visibleTranscript = []
        conversationPulse = initialPulse

        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isRecording {
                try? await Task.sleep(for: .seconds(1))
                guard self.isRecording else { break }
                self.elapsedSeconds += 1
            }
        }

        pulseTask = Task { [weak self] in
            guard let self else { return }
            let states = self.demoPulseSequence
            var index = 0

            while !Task.isCancelled && self.isRecording {
                try? await Task.sleep(for: .seconds(3))
                guard self.isRecording else { break }
                index = (index + 1) % states.count
                self.conversationPulse = states[index]
            }
        }

        transcriptTask = Task { [weak self] in
            guard let self else { return }
            for beat in self.activeSession.scenario.transcript {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(max(0.8, beat.offsetSeconds == 0 ? 0.5 : 1.2)))
                guard self.isRecording else { break }
                self.visibleTranscript.append(beat)
            }
        }
    }

    func stop() {
        isRecording = false
        timerTask?.cancel()
        transcriptTask?.cancel()
        pulseTask?.cancel()
        visibleTranscript = activeSession.scenario.transcript
    }

    private var demoPulseSequence: [Double] {
        switch activeSession.setup.conversationType {
        case .conflict:
            return [0.44, 0.56, 0.28, 0.68]
        case .repair:
            return [0.48, 0.36, 0.6, 0.74]
        case .planning:
            return [0.58, 0.46, 0.34, 0.7]
        case .vulnerableConversation:
            return [0.62, 0.42, 0.31, 0.72]
        case .decision:
            return [0.55, 0.39, 0.3, 0.67]
        case .other:
            return [0.6, 0.45, 0.32, 0.7]
        case .checkIn, .none:
            return [0.74, 0.58, 0.36, 0.78]
        }
    }

    private var initialPulse: Double {
        switch activeSession.setup.conversationType {
        case .conflict:
            return 0.4
        case .repair:
            return 0.48
        case .planning:
            return 0.55
        case .vulnerableConversation:
            return 0.58
        case .decision:
            return 0.52
        case .other:
            return 0.58
        case .checkIn, .none:
            return 0.72
        }
    }

}
