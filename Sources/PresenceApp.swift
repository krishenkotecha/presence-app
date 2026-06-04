import AVFoundation
import Speech
import SwiftUI

@main
struct PresenceApp: App {
    private enum PrototypeTrack {
        case v1
        case v2Starter
    }

    private let activeTrack: PrototypeTrack = .v2Starter
    @StateObject private var store = SessionStore()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            activeRoot
                .environmentObject(store)
                .environmentObject(themeStore)
        }
    }

    @ViewBuilder
    private var activeRoot: some View {
        switch activeTrack {
        case .v1:
            RootView()
        case .v2Starter:
            PresenceV2StarterRootView()
        }
    }
}

struct PresenceV2StarterRootView: View {
    var body: some View {
        NavigationStack {
            PresenceV2HomeView()
        }
    }
}

private struct PresenceV2SuccessCapture {
    let participantOne: String
    let participantTwo: String
}

private enum PresenceV2BackendConfig {
    // Simulator: localhost works. Physical device: use Mac's LAN IP (e.g. "http://192.168.x.x:8000/...")
    static let analyzeURLString = "http://127.0.0.1:8000/api/v1/conversations/analyze"
    static let workOnURLString  = "http://127.0.0.1:8000/api/v1/relationships/work-on"
}

private struct PresenceV2HomeView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Presence")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text("A relationship mirror for the conversations that matter.")
                        .font(.system(size: 32, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("Presence sits between the two of you, listens, and helps you understand how you’re showing up together over time.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.top, 8)

                NavigationLink {
                    PresenceV2SuccessDefinitionView()
                } label: {
                    actionCard(
                        eyebrow: "Start a conversation",
                        title: "Set one shared goal, then let Presence listen.",
                        detail: "Before you start, define what success looks like for this conversation."
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PresenceV2WorkOnView()
                } label: {
                    actionCard(
                        eyebrow: "What should we work on?",
                        title: "See the one or two relationship habits worth focusing on next.",
                        detail: "Presence turns repeated conversations into simple coaching for the two of you."
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What this version is for")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("This simpler version stays strictly focused on couples: start a conversation, define success, listen, and get relationship-specific insight back.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Presence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func actionCard(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)
                .tracking(0.7)

            Text(title)
                .font(.system(size: 24, weight: .semibold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("Open")
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
            .foregroundStyle(theme.accentStrong)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }
}

private struct PresenceV2SuccessDefinitionView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @StateObject private var capture = PresenceSpeechCaptureManager()
    @State private var partnerOneResponse: String?
    @State private var partnerTwoResponse: String?
    @State private var recordingPartner: PartnerSlot?

    private enum PartnerSlot: String {
        case partnerOne = "You"
        case partnerTwo = "Your partner"

        var title: String { rawValue }
        var prompt: String {
            switch self {
            case .partnerOne:
                return "What would make this feel like a good conversation for you?"
            case .partnerTwo:
                return "What would you want to feel or understand by the end?"
            }
        }

        var seededResponse: String {
            switch self {
            case .partnerOne:
                return "I want us to stay calm and actually feel like we understand each other before we solve anything."
            case .partnerTwo:
                return "I want to feel heard first, then leave with a clear plan we both believe in."
            }
        }
    }

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Before you start")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(0.7)

                    Text("What does success look like for this conversation?")
                        .font(.system(size: 32, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("Have each partner answer this out loud. Presence will wait until it has heard both of you before it starts listening.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                VStack(spacing: 14) {
                    partnerCaptureCard(for: .partnerOne, response: partnerOneResponse)
                    partnerCaptureCard(for: .partnerTwo, response: partnerTwoResponse)
                }

                Text("Presence will listen to the conversation, then send the audio and your shared success definition to the API for insight generation.")
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)

                if let permissionMessage = capture.permissionMessage {
                    Text(permissionMessage)
                        .font(.system(.footnote, design: theme.bodyDesign))
                        .foregroundStyle(theme.accentWarm)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink {
                    PresenceV2ConversationView(successCapture: resolvedSuccessCapture)
                } label: {
                    Text("Start listening")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PresenceV2PrimaryButtonStyle(theme: theme))
                .disabled(!hasBothResponses || recordingPartner != nil)
                .opacity(hasBothResponses && recordingPartner == nil ? 1 : 0.55)
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Start")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var resolvedSuccessCapture: PresenceV2SuccessCapture {
        let first = partnerOneResponse ?? "I want us to feel heard before we solve anything."
        let second = partnerTwoResponse ?? "I want to feel understood first, then land on a plan together."
        return PresenceV2SuccessCapture(
            participantOne: first,
            participantTwo: second
        )
    }

    private var hasBothResponses: Bool {
        partnerOneResponse != nil && partnerTwoResponse != nil
    }

    private func partnerCaptureCard(for slot: PartnerSlot, response: String?) -> some View {
        let isRecording = recordingPartner == slot
        let isComplete = response != nil

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(slot.title)
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(0.7)

                    Text(slot.prompt)
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)
                }

                Spacer()

                Button {
                    startCapture(for: slot)
                } label: {
                    Image(systemName: isRecording ? "waveform.circle.fill" : (isComplete ? "checkmark.circle.fill" : "mic.circle.fill"))
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(isRecording ? theme.accentWarm : theme.accentSuccess)
                }
                .buttonStyle(.plain)
                .disabled(recordingPartner != nil && recordingPartner != slot)
            }

            if isRecording {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(theme.accentWarm)

                    Text("Listening for \(slot.title.lowercased())…")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                if !capture.transcript.isEmpty {
                    Text("“\(capture.transcript)”")
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let response {
                Text("“\(response)”")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Captured for the shared goal.")
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            } else {
                Text("Tap the mic and let them answer in their own words.")
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke((isRecording ? theme.accentWarm : theme.border).opacity(0.84), lineWidth: 1)
        )
    }

    private func startCapture(for slot: PartnerSlot) {
        if recordingPartner == slot {
            let spokenText = capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalText = spokenText.isEmpty ? slot.seededResponse : spokenText

            switch slot {
            case .partnerOne:
                partnerOneResponse = finalText
            case .partnerTwo:
                partnerTwoResponse = finalText
            }

            capture.stop()
            recordingPartner = nil
            return
        }

        guard recordingPartner == nil else { return }
        recordingPartner = slot

        Task {
            let started = await capture.start()
            if !started {
                recordingPartner = nil
            }
        }
    }
}

private struct PresenceV2ConversationView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let successCapture: PresenceV2SuccessCapture
    @StateObject private var monitor = PresenceV2ConversationMonitor()
    @State private var showProcessing = false

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ZStack {
            listeningBackdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    listeningPill(title: "Conversation", systemImage: "heart.text.square.fill")

                    Spacer()

                    listeningPill(title: formattedElapsed, systemImage: "record.circle.fill", emphasize: true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)

                Spacer()

                VStack(spacing: 14) {
                    Text(stageTitle)
                        .font(.system(size: 44, weight: .semibold, design: theme.displayDesign))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text(stageCaption)
                        .font(.system(.title3, design: theme.bodyDesign))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    if let permissionMessage = monitor.permissionMessage {
                        Text(permissionMessage)
                            .font(.system(.footnote, design: theme.bodyDesign))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    } else if !monitor.transcript.isEmpty {
                        Text("“\(monitor.transcript)”")
                            .font(.system(.footnote, design: theme.bodyDesign).weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text("Success looks like")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(successDefinition)
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        monitor.stop()
                        showProcessing = true
                    } label: {
                        Text("Stop and analyze")
                            .font(.system(.headline, design: theme.bodyDesign))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PresenceV2StopButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showProcessing) {
            PresenceV2ProcessingView(
                submission: PresenceV2ConversationSubmission(
                    sessionID: UUID().uuidString,
                    startedAt: monitor.startedAt ?? Date(),
                    endedAt: Date(),
                    durationSeconds: monitor.elapsedSeconds,
                    participantOneLabel: "You",
                    participantTwoLabel: "Your partner",
                    participantOneSuccessDefinition: successCapture.participantOne,
                    participantTwoSuccessDefinition: successCapture.participantTwo,
                    conversationAudioURL: monitor.recordedFileURL
                )
            )
        }
        .onAppear {
            monitor.start()
        }
        .animation(.easeInOut(duration: 0.8), value: monitor.conversationPulse)
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
            .foregroundStyle(Color.white)
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
        switch monitor.conversationPulse {
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
        switch monitor.conversationPulse {
        case 0.66...:
            return "Stay with it"
        case 0.4..<0.66:
            return "A little tense"
        default:
            return "Time to reset"
        }
    }

    private var stageCaption: String {
        switch monitor.conversationPulse {
        case 0.66...:
            return "The conversation feels open right now."
        case 0.4..<0.66:
            return "This is a moment to slow down and keep listening."
        default:
            return "Tension is rising. A calmer response will help."
        }
    }

    private var formattedElapsed: String {
        let minutes = monitor.elapsedSeconds / 60
        let seconds = monitor.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var successDefinition: String {
        "You: \(successCapture.participantOne)\n\nYour partner: \(successCapture.participantTwo)"
    }
}

private struct PresenceV2ProcessingView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let submission: PresenceV2ConversationSubmission
    @State private var showInsight = false
    @State private var analysis: PresenceV2AnalysisResponse?
    @State private var errorMessage: String?

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.accentSuccess)
                .scaleEffect(1.25)

            Text("Generating insight")
                .font(.system(size: 30, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("Sending the conversation audio and your definition of success to the API.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Success definition")
                    .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                    .foregroundStyle(theme.accentSuccess)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Text("You: \(submission.participantOneSuccessDefinition)\n\nYour partner: \(submission.participantTwoSuccessDefinition)")
                    .font(.system(.body, design: theme.bodyDesign))
                    .foregroundStyle(theme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.border.opacity(0.84), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.accentWarm)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Analyzing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showInsight) {
            if let analysis {
                PresenceV2InsightView(analysis: analysis)
            }
        }
        .task {
            guard !showInsight else { return }
            let result = await PresenceV2BackendClient.shared.analyze(submission: submission)
            switch result {
            case .success(let analysis):
                self.analysis = analysis
            case .failure:
                self.errorMessage = "Backend not configured yet, so Presence is showing a local demo analysis for now."
                self.analysis = PresenceV2AnalysisResponse.mock(from: submission)
            }
            try? await Task.sleep(for: .seconds(0.8))
            showInsight = true
        }
    }
}

private struct PresenceV2InsightView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let analysis: PresenceV2AnalysisResponse

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Results")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(0.7)

                    Text(analysis.summary.headline)
                        .font(.system(size: 30, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("\(formattedDuration) listened • analyzed against your goal for the conversation")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                insightPanel(
                    title: "Your shared definition of success",
                    body: analysis.successDefinition.shared
                )

                metricRow
                keyMomentsSection
                unmetNeedsSection
                nextTimeSection
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var metricRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Conversation readout")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                resultMetric(
                    title: "Balance of words",
                    value: "\(analysis.metrics.wordBalance.participantOnePercent) / \(analysis.metrics.wordBalance.participantTwoPercent)",
                    detail: analysis.metrics.wordBalance.label
                )
                resultMetric(
                    title: "Interruptions",
                    value: "\(analysis.metrics.interruptions.total)",
                    detail: analysis.metrics.interruptions.label
                )
                resultMetric(
                    title: "Connection score",
                    value: "\(analysis.metrics.connectionScore.score)",
                    detail: analysis.metrics.connectionScore.deltaLabel
                )
                resultMetric(
                    title: "Repair attempts",
                    value: "\(analysis.metrics.repairAttempts.total)",
                    detail: analysis.metrics.repairAttempts.label
                )
            }
        }
    }

    private var keyMomentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key moments")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text("Where the health of the conversation changed most dramatically.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 12) {
                ForEach(analysis.keyMoments) { moment in
                    keyMomentRow(moment: moment)
                }
            }
        }
    }

    private var unmetNeedsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What each person needed, but didn’t get")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            VStack(spacing: 12) {
                ForEach(analysis.unmetNeeds) { item in
                    personNeedCard(person: item.person, need: item.need)
                }
            }
        }
    }

    private var nextTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Here’s what to try next time")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            VStack(spacing: 12) {
                ForEach(analysis.nextTime) { item in
                    nextStepCard(person: item.person, step: item.tryNext)
                }
            }
        }
    }

    private func insightPanel(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text(body)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func resultMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.system(.caption, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func keyMomentRow(moment: PresenceV2AnalysisResponse.KeyMoment) -> some View {
        let accent = moment.type == .positive ? theme.accentSuccess : theme.accentWarm
        let tint = moment.type == .positive ? theme.accentSuccess.opacity(0.08) : theme.accentWarm.opacity(0.09)

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)

                Rectangle()
                    .fill(accent.opacity(0.22))
                    .frame(width: 2)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatTimestamp(moment.timestampMs))
                    .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                    .foregroundStyle(accent)

                Text(moment.title)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Text("“\(moment.quote)”")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                    .foregroundStyle(theme.primaryText)
                    .padding(.top, 2)

                Text(moment.explanation)
                    .font(.system(.subheadline, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }

    private func personNeedCard(person: String, need: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(person)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)

            Text(need)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func nextStepCard(person: String, step: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(person)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)

            Text(step)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private var formattedDuration: String {
        let minutes = max(1, analysis.durationSeconds / 60)
        return "\(minutes)m"
    }

    private func formatTimestamp(_ timestampMs: Int) -> String {
        let totalSeconds = timestampMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct PresenceV2WorkOnView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var insight = PresenceV2WorkOnResponse.mock
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What should we work on?")
                        .font(.system(size: 30, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)

                    Text("Presence looks across repeated conversations and shows you what tends to matter most between the two of you.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(theme.accentSuccess)

                        Text("Looking across your recent conversations…")
                            .font(.system(.subheadline, design: theme.bodyDesign))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(.footnote, design: theme.bodyDesign))
                        .foregroundStyle(theme.accentWarm)
                        .fixedSize(horizontal: false, vertical: true)
                }

                heroRecommendation
                whyThisMattersSection
                patternsSection
                improvingSection
                workOnListSection
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Work on")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            guard isLoading else { return }
            let result = await PresenceV2BackendClient.shared.fetchWorkOn()
            switch result {
            case .success(let response):
                insight = response
            case .failure:
                errorMessage = "Backend not configured yet, so Presence is showing local relationship patterns for now."
                insight = .mock
            }
            isLoading = false
        }
    }

    private var heroRecommendation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most worth working on now")
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)
                .tracking(0.7)

            Text(insight.primaryFocus.title)
                .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text(insight.primaryFocus.summary)
                .font(.system(.body, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statPill(title: insight.primaryFocus.frequencyLabel, tint: theme.accentSuccess.opacity(0.14), textColor: theme.accentStrong)
                statPill(title: insight.primaryFocus.contextLabel, tint: theme.chipBackground.opacity(0.95), textColor: theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(theme.border.opacity(0.9), lineWidth: 1)
        )
    }

    private var whyThisMattersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Why this matters")

            VStack(spacing: 10) {
                ForEach(insight.whyThisMatters) { item in
                    insightRow(title: item.title, detail: item.detail, accent: .neutral)
                }
            }
        }
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Patterns between you")

            VStack(spacing: 10) {
                ForEach(insight.relationshipPatterns) { pattern in
                    insightRow(title: pattern.title, detail: pattern.detail, accent: .positive)
                }
            }
        }
    }

    private var improvingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What’s improving")

            VStack(spacing: 10) {
                ForEach(insight.improving) { item in
                    insightRow(title: item.title, detail: item.detail, accent: .positive)
                }
            }
        }
    }

    private var workOnListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("A few things to work on")

            VStack(spacing: 10) {
                ForEach(insight.workOnAreas) { item in
                    insightRow(title: item.title, detail: item.detail, accent: .watch)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: theme.bodyDesign))
            .foregroundStyle(theme.primaryText)
    }

    private func statPill(title: String, tint: Color, textColor: Color) -> some View {
        Text(title)
            .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint, in: Capsule())
    }

    private func insightRow(title: String, detail: String, accent: WorkOnAccent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(accent.color(for: theme))
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    Text(detail)
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private enum WorkOnAccent {
        case neutral
        case positive
        case watch

        func color(for theme: PresenceTheme) -> Color {
            switch self {
            case .neutral:
                return theme.accentStrong.opacity(0.7)
            case .positive:
                return theme.accentSuccess
            case .watch:
                return theme.accentWarm
            }
        }
    }
}

private struct PresenceV2WorkOnResponse: Decodable {
    struct PrimaryFocus: Decodable {
        let title: String
        let summary: String
        let frequencyLabel: String
        let contextLabel: String

        enum CodingKeys: String, CodingKey {
            case title
            case summary
            case frequencyLabel = "frequency_label"
            case contextLabel = "context_label"
        }
    }

    struct InsightItem: Decodable, Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    let relationshipID: String?
    let timeWindow: String?
    let primaryFocus: PrimaryFocus
    let whyThisMatters: [InsightItem]
    let relationshipPatterns: [InsightItem]
    let improving: [InsightItem]
    let workOnAreas: [InsightItem]

    enum CodingKeys: String, CodingKey {
        case relationshipID = "relationship_id"
        case timeWindow = "time_window"
        case primaryFocus = "primary_focus"
        case whyThisMatters = "why_this_matters"
        case relationshipPatterns = "relationship_patterns"
        case improving
        case workOnAreas = "work_on_areas"
    }

    static let mock = PresenceV2WorkOnResponse(
        relationshipID: nil,
        timeWindow: "90d",
        primaryFocus: .init(
            title: "Stay with the feeling before moving into solutions.",
            summary: "The two of you tend to reconnect when the emotional part lands first. When one of you starts fixing too early, the conversation becomes more procedural and less connected.",
            frequencyLabel: "6 of your last 10 conversations",
            contextLabel: "Especially true in money and planning"
        ),
        whyThisMatters: [
            .init(
                title: "Connection is stronger when you slow down first",
                detail: "When feelings are named before logistics, your connection score is about 14 points higher than usual."
            ),
            .init(
                title: "This pattern shows up in harder conversations",
                detail: "It appears most often in discussions about money, planning, and chores, especially when you are both already tired."
            ),
            .init(
                title: "The first defensive turn predicts the rest",
                detail: "Once either of you starts explaining intent instead of reflecting impact, interruptions rise and the conversation gets more transactional."
            )
        ],
        relationshipPatterns: [
            .init(
                title: "One of you tends to want reassurance while the other wants clarity",
                detail: "The most productive conversations happen when both needs are made visible early instead of competing under the surface."
            ),
            .init(
                title: "Money conversations become more efficient and less curious",
                detail: "You both speak more directly and ask fewer follow-up questions when the topic turns to budgets or planning."
            ),
            .init(
                title: "Repair happens faster once the real concern is named",
                detail: "When one of you says what you are actually afraid of, the conversation usually softens within a few minutes."
            )
        ],
        improving: [
            .init(
                title: "Interruptions are down this month",
                detail: "You are both leaving more space before jumping in, especially in shorter check-in conversations."
            ),
            .init(
                title: "You are recovering from tension faster",
                detail: "Even when conversations get sharp, you are finding your way back sooner than you were a few weeks ago."
            ),
            .init(
                title: "Shared goals are helping",
                detail: "Conversations that begin with a clear idea of success end warmer and feel more collaborative."
            )
        ],
        workOnAreas: [
            .init(
                title: "Name the feeling underneath the logistics",
                detail: "Try to say the emotional point out loud before discussing what the plan should be."
            ),
            .init(
                title: "Catch the first defensive response",
                detail: "The moment one of you starts explaining instead of reflecting is usually the moment the conversation turns."
            ),
            .init(
                title: "Define success together earlier",
                detail: "A simple shared goal at the start tends to keep the conversation from drifting into old patterns."
            )
        ]
    )

    private init(
        relationshipID: String?,
        timeWindow: String?,
        primaryFocus: PrimaryFocus,
        whyThisMatters: [InsightItem],
        relationshipPatterns: [InsightItem],
        improving: [InsightItem],
        workOnAreas: [InsightItem]
    ) {
        self.relationshipID = relationshipID
        self.timeWindow = timeWindow
        self.primaryFocus = primaryFocus
        self.whyThisMatters = whyThisMatters
        self.relationshipPatterns = relationshipPatterns
        self.improving = improving
        self.workOnAreas = workOnAreas
    }
}

private struct PresenceV2ConversationSubmission {
    let sessionID: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let participantOneLabel: String
    let participantTwoLabel: String
    let participantOneSuccessDefinition: String
    let participantTwoSuccessDefinition: String
    let conversationAudioURL: URL?
}

private struct PresenceV2AnalysisResponse: Decodable {
    struct Summary: Decodable {
        let headline: String
        let subheadline: String
    }

    struct SuccessDefinition: Decodable {
        let participantOne: String
        let participantTwo: String
        let shared: String
    }

    struct Metrics: Decodable {
        struct WordBalance: Decodable {
            let participantOnePercent: Int
            let participantTwoPercent: Int
            let label: String
        }

        struct Interruptions: Decodable {
            let total: Int
            let participantOne: Int
            let participantTwo: Int
            let label: String
        }

        struct ConnectionScore: Decodable {
            let score: Int
            let deltaLabel: String
        }

        struct RepairAttempts: Decodable {
            let total: Int
            let label: String
        }

        let wordBalance: WordBalance
        let interruptions: Interruptions
        let connectionScore: ConnectionScore
        let repairAttempts: RepairAttempts
    }

    struct KeyMoment: Decodable, Identifiable {
        enum MomentType: String, Decodable {
            case positive
            case negative
        }

        let id: UUID
        let timestampMs: Int
        let type: MomentType
        let title: String
        let quote: String
        let speaker: String
        let explanation: String

        init(id: UUID = UUID(), timestampMs: Int, type: MomentType, title: String, quote: String, speaker: String, explanation: String) {
            self.id = id
            self.timestampMs = timestampMs
            self.type = type
            self.title = title
            self.quote = quote
            self.speaker = speaker
            self.explanation = explanation
        }

        enum CodingKeys: String, CodingKey {
            case timestampMs = "timestamp_ms"
            case type
            case title
            case quote
            case speaker
            case explanation
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.timestampMs = try container.decode(Int.self, forKey: .timestampMs)
            self.type = try container.decode(MomentType.self, forKey: .type)
            self.title = try container.decode(String.self, forKey: .title)
            self.quote = try container.decode(String.self, forKey: .quote)
            self.speaker = try container.decode(String.self, forKey: .speaker)
            self.explanation = try container.decode(String.self, forKey: .explanation)
        }
    }

    struct UnmetNeed: Decodable, Identifiable {
        let id = UUID()
        let person: String
        let need: String
    }

    struct NextTime: Decodable, Identifiable {
        let id = UUID()
        let person: String
        let tryNext: String

        enum CodingKeys: String, CodingKey {
            case person
            case tryNext = "try"
        }
    }

    let sessionID: String
    let status: String
    let summary: Summary
    let successDefinition: SuccessDefinition
    let metrics: Metrics
    let keyMoments: [KeyMoment]
    let unmetNeeds: [UnmetNeed]
    let nextTime: [NextTime]
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case status
        case summary
        case successDefinition = "success_definition"
        case metrics
        case keyMoments = "key_moments"
        case unmetNeeds = "unmet_needs"
        case nextTime = "next_time"
        case durationSeconds = "duration_seconds"
    }

    static func mock(from submission: PresenceV2ConversationSubmission) -> PresenceV2AnalysisResponse {
        PresenceV2AnalysisResponse(
            sessionID: submission.sessionID,
            status: "completed",
            summary: Summary(
                headline: "You were closest to success when the conversation stayed balanced instead of sliding into explanation.",
                subheadline: "The biggest shift happened once the emotional point landed before either of you tried to solve it."
            ),
            successDefinition: SuccessDefinition(
                participantOne: submission.participantOneSuccessDefinition,
                participantTwo: submission.participantTwoSuccessDefinition,
                shared: "You both wanted understanding before problem-solving."
            ),
            metrics: Metrics(
                wordBalance: .init(participantOnePercent: 54, participantTwoPercent: 46, label: "Fairly even"),
                interruptions: .init(total: 7, participantOne: 5, participantTwo: 2, label: "Mostly from you"),
                connectionScore: .init(score: 78, deltaLabel: "+9 once you slowed down"),
                repairAttempts: .init(total: 3, label: "Two landed well")
            ),
            keyMoments: [
                .init(timestampMs: 190000, type: .negative, title: "Tension rose", quote: "Yeah, but that’s not what I meant.", speaker: "You", explanation: "This shifted the conversation from impact to intent, which made your partner feel less met in the emotional part."),
                .init(timestampMs: 525000, type: .positive, title: "Connection improved", quote: "I can see why that felt lonely.", speaker: "You", explanation: "This was the first moment the feeling landed before the problem got solved, and the conversation softened immediately."),
                .init(timestampMs: 680000, type: .positive, title: "You got back on track", quote: "What I actually need is to feel like we’re on the same side.", speaker: "Your partner", explanation: "Once the underlying need was named directly, the conversation stopped circling and became more collaborative.")
            ],
            unmetNeeds: [
                .init(person: "You", need: "Reassurance that the conversation wasn’t becoming a character judgment."),
                .init(person: "Your partner", need: "A clearer sign that the emotional part landed before the problem-solving started.")
            ],
            nextTime: [
                .init(person: "For you", tryNext: "Before explaining your intent, reflect back the feeling you think you heard in one sentence."),
                .init(person: "For your partner", tryNext: "Name the underlying need earlier, before the conversation gets pulled into logistics.")
            ],
            durationSeconds: submission.durationSeconds
        )
    }

    private init(
        sessionID: String,
        status: String,
        summary: Summary,
        successDefinition: SuccessDefinition,
        metrics: Metrics,
        keyMoments: [KeyMoment],
        unmetNeeds: [UnmetNeed],
        nextTime: [NextTime],
        durationSeconds: Int
    ) {
        self.sessionID = sessionID
        self.status = status
        self.summary = summary
        self.successDefinition = successDefinition
        self.metrics = metrics
        self.keyMoments = keyMoments
        self.unmetNeeds = unmetNeeds
        self.nextTime = nextTime
        self.durationSeconds = durationSeconds
    }
}

private actor PresenceV2BackendClient {
    static let shared = PresenceV2BackendClient()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func analyze(submission: PresenceV2ConversationSubmission) async -> Result<PresenceV2AnalysisResponse, Error> {
        guard let url = URL(string: PresenceV2BackendConfig.analyzeURLString), !PresenceV2BackendConfig.analyzeURLString.isEmpty else {
            return .failure(BackendError.notConfigured)
        }

        guard let audioURL = submission.conversationAudioURL else {
            return .failure(BackendError.missingAudio)
        }

        do {
            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let body = try buildMultipartBody(submission: submission, audioURL: audioURL, boundary: boundary)
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }

            let analysis = try JSONDecoder().decode(PresenceV2AnalysisResponse.self, from: data)
            return .success(analysis)
        } catch {
            return .failure(error)
        }
    }

    func fetchWorkOn() async -> Result<PresenceV2WorkOnResponse, Error> {
        guard let url = URL(string: PresenceV2BackendConfig.workOnURLString), !PresenceV2BackendConfig.workOnURLString.isEmpty else {
            return .failure(BackendError.notConfigured)
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }

            let workOn = try JSONDecoder().decode(PresenceV2WorkOnResponse.self, from: data)
            return .success(workOn)
        } catch {
            return .failure(error)
        }
    }

    private func buildMultipartBody(submission: PresenceV2ConversationSubmission, audioURL: URL, boundary: String) throws -> Data {
        var data = Data()

        func appendField(name: String, value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "session_id", value: submission.sessionID)
        appendField(name: "started_at", value: ISO8601DateFormatter().string(from: submission.startedAt))
        appendField(name: "ended_at", value: ISO8601DateFormatter().string(from: submission.endedAt))
        appendField(name: "duration_seconds", value: String(submission.durationSeconds))
        appendField(name: "participant_one_label", value: submission.participantOneLabel)
        appendField(name: "participant_two_label", value: submission.participantTwoLabel)
        appendField(name: "participant_one_success_definition", value: submission.participantOneSuccessDefinition)
        appendField(name: "participant_two_success_definition", value: submission.participantTwoSuccessDefinition)
        appendField(name: "prototype_track", value: "v2")

        let fileData = try Data(contentsOf: audioURL)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"conversation_audio\"; filename=\"conversation.caf\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/x-caf\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return data
    }

    enum BackendError: Error {
        case notConfigured
        case missingAudio
        case badResponse
    }
}

@MainActor
private final class PresenceSpeechCaptureManager: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permissionMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioFile: AVAudioFile?
    private(set) var recordedFileURL: URL?

    func start() async -> Bool {
        if isRecording { return true }

        let granted = await requestPermissionsIfNeeded()
        guard granted else { return false }

        do {
            try configureAndStart()
            return true
        } catch {
            permissionMessage = "Presence couldn’t start the microphone right now."
            stop()
            return false
        }
    }

    func stop() {
        guard isRecording || recognitionTask != nil else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        isRecording = false

        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        if !speechAuthorized || !micGranted {
            permissionMessage = "Presence needs microphone and speech recognition access to capture both partners."
            return false
        }

        permissionMessage = nil
        return true
    }

    private func configureAndStart() throws {
        transcript = ""
        permissionMessage = nil
        recordedFileURL = temporaryRecordingURL()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        if let recordedFileURL {
            audioFile = try AVAudioFile(forWriting: recordedFileURL, settings: format.settings)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.isRecording = false
                }
            }
        }
    }

    private func temporaryRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
    }
}

@MainActor
private final class PresenceV2ConversationMonitor: ObservableObject {
    @Published var elapsedSeconds = 0
    @Published var conversationPulse: Double = 0.78
    @Published var transcript = ""
    @Published var permissionMessage: String?
    private(set) var startedAt: Date?

    private var timer: Timer?
    private let scriptedPulse: [Double] = [0.84, 0.72, 0.55, 0.38, 0.62, 0.8]
    private var pulseIndex = 0
    private let capture = PresenceSpeechCaptureManager()

    func start() {
        stop()
        elapsedSeconds = 0
        conversationPulse = scriptedPulse.first ?? 0.78
        pulseIndex = 0
        transcript = ""
        permissionMessage = nil
        startedAt = Date()

        Task { [weak self] in
            guard let self else { return }
            let started = await self.capture.start()
            self.permissionMessage = self.capture.permissionMessage
            if !started {
                self.permissionMessage = self.capture.permissionMessage
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                self.transcript = self.capture.transcript
                self.permissionMessage = self.capture.permissionMessage
                if self.elapsedSeconds.isMultiple(of: 3) {
                    self.pulseIndex = (self.pulseIndex + 1) % self.scriptedPulse.count
                    self.conversationPulse = self.scriptedPulse[self.pulseIndex]
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        capture.stop()
        transcript = capture.transcript
        permissionMessage = capture.permissionMessage
    }

    var recordedFileURL: URL? {
        capture.recordedFileURL
    }
}

private struct PresenceV2PrimaryButtonStyle: ButtonStyle {
    let theme: PresenceTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                theme.primaryButtonBackground.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .foregroundStyle(theme.primaryButtonText)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .shadow(color: theme.accentSuccess.opacity(0.14), radius: 14, x: 0, y: 10)
    }
}

private struct PresenceV2StopButtonStyle: ButtonStyle {
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
