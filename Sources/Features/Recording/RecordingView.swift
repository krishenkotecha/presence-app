import SwiftUI

struct RecordingView: View {
    let activeSession: ActiveConversation

    @EnvironmentObject private var themeStore: ThemeStore
    @StateObject private var simulator: RecordingSimulator
    @State private var shouldNavigateToCheckIn = false

    private var theme: PresenceTheme {
        themeStore.current
    }

    init(activeSession: ActiveConversation) {
        self.activeSession = activeSession
        _simulator = StateObject(wrappedValue: RecordingSimulator(activeSession: activeSession))
    }

    var body: some View {
        ZStack {
            listeningBackdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                Spacer()

                centerStage
                    .padding(.horizontal, 24)

                Spacer()

                bottomAction
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $shouldNavigateToCheckIn) {
            CalibrationView(activeSession: activeSession)
        }
        .onAppear {
            simulator.start()
        }
        .animation(.easeInOut(duration: 0.8), value: simulator.conversationPulse)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            listeningPill(
                title: activeSession.setup.conversationTypeDisplayLabel ?? "Conversation",
                systemImage: activeSession.setup.conversationType?.symbolName ?? "waveform"
            )

            Spacer()

            listeningPill(title: formattedElapsed, systemImage: "record.circle.fill", emphasize: true)
        }
        .foregroundStyle(Color.white)
    }

    private var centerStage: some View {
        VStack(spacing: 14) {
            Text(stageTitle)
                .font(.system(size: 44, weight: .semibold, design: theme.displayDesign))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(stageCaption)
                .font(.system(.title3, design: theme.bodyDesign))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 14) {
            if let relationship = activeSession.setup.relationshipDisplayLabel {
                Text("Listening to your \(relationship.lowercased()) conversation")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.76))
            }

            Button {
                simulator.stop()
                shouldNavigateToCheckIn = true
            } label: {
                Text("Stop and review")
                    .font(.system(.headline, design: theme.bodyDesign))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(ListeningStopButtonStyle())
        }
    }

    private func listeningPill(title: String, systemImage: String, emphasize: Bool = false) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(emphasize ? 0.2 : 0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(emphasize ? 0.22 : 0.14), lineWidth: 1)
            )
    }

    private var listeningBackdrop: some View {
        let palette = pulsePalette

        return ZStack {
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: -120, y: -280)

            Circle()
                .fill(palette.glow.opacity(0.4))
                .frame(width: 360, height: 360)
                .blur(radius: 54)
                .offset(x: 110, y: 220)
        }
    }

    private var pulsePalette: (top: Color, bottom: Color, glow: Color) {
        switch simulator.conversationPulse {
        case 0.66...:
            return (
                top: Color(red: 0.19, green: 0.61, blue: 0.42),
                bottom: Color(red: 0.09, green: 0.45, blue: 0.32),
                glow: Color(red: 0.57, green: 0.9, blue: 0.68)
            )
        case 0.4..<0.66:
            return (
                top: Color(red: 0.9, green: 0.64, blue: 0.2),
                bottom: Color(red: 0.73, green: 0.46, blue: 0.11),
                glow: Color(red: 0.99, green: 0.83, blue: 0.44)
            )
        default:
            return (
                top: Color(red: 0.82, green: 0.24, blue: 0.23),
                bottom: Color(red: 0.58, green: 0.09, blue: 0.11),
                glow: Color(red: 1.0, green: 0.56, blue: 0.51)
            )
        }
    }

    private var stageTitle: String {
        switch simulator.conversationPulse {
        case 0.66...:
            return "Stay with it"
        case 0.4..<0.66:
            return "A little tense"
        default:
            return "Time to reset"
        }
    }

    private var stageCaption: String {
        switch simulator.conversationPulse {
        case 0.66...:
            return "The conversation feels open right now."
        case 0.4..<0.66:
            return "This is a moment to slow down and keep listening."
        default:
            return "Tension is rising. A calmer response will help."
        }
    }

    private var formattedElapsed: String {
        let minutes = simulator.elapsedSeconds / 60
        let seconds = simulator.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ListeningStopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(configuration.isPressed ? 0.78 : 0.92),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .foregroundStyle(Color.black.opacity(0.78))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)
    }
}
