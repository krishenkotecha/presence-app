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
    // ONE place to configure the backend.
    // Simulator: "http://127.0.0.1:8000". Physical device: your Mac's LAN IP, e.g. "http://192.168.1.20:8000".
    // Leave empty ("") to force the on-device demo everywhere.
    static let baseURLString = "http://127.0.0.1:8000"

    static var apiRoot: String { baseURLString.isEmpty ? "" : baseURLString + "/api/v1" }
    static var analyzeURLString: String { apiRoot.isEmpty ? "" : apiRoot + "/conversations/analyze" }
    static var workOnURLString: String { apiRoot.isEmpty ? "" : apiRoot + "/relationships/work-on" }
    static var latestURLString: String { apiRoot.isEmpty ? "" : apiRoot + "/conversations/latest" }
    // Solo (single-user) reflection — text only, no audio.
    static var reflectURLString: String { apiRoot.isEmpty ? "" : apiRoot + "/reflections/analyze" }
    static func feedbackURLString(sessionID: String) -> String {
        apiRoot.isEmpty ? "" : apiRoot + "/conversations/\(sessionID)/feedback"
    }
}

private enum HomeAudience: String, CaseIterable, Identifiable {
    case solo, couple
    var id: String { rawValue }
    var label: String { self == .solo ? "Just me" : "With my partner" }
}

private struct PresenceV2HomeView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var latestAnalysis: PresenceV2AnalysisResponse?
    @State private var isLoadingLatest = false
    @State private var showLatest = false
    // One explicit choice up front — who is this for — so each mode's actions show alone.
    @State private var audience: HomeAudience = .solo

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presence")
                        .font(.system(size: 14, weight: .bold, design: theme.bodyDesign))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(1.4)

                    Text("Understand each other better.")
                        .font(.system(size: 32, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                // One clear choice up front: who is this for.
                audienceToggle

                if audience == .solo {
                    modeDescriptor("Just you. Nothing recorded, nothing shared — work through a moment in your own words.")

                    NavigationLink {
                        PresenceSoloInputView()
                    } label: {
                        actionCard(
                            eyebrow: "Make sense of a moment",
                            title: "Decode what they said, prep for a hard talk, or process what happened.",
                            detail: "Type or speak — Presence helps you understand and respond."
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    modeDescriptor("Sit down together. Define what success looks like, then let Presence listen.")

                    NavigationLink {
                        PresenceV2SuccessDefinitionView()
                    } label: {
                        actionCard(
                            eyebrow: "Start a conversation",
                            title: "Set one shared goal, then let Presence listen.",
                            detail: "Define what success looks like for this conversation first."
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PresenceV2WorkOnView()
                    } label: {
                        secondaryActionRow(
                            title: "What should we work on?",
                            subtitle: "Look back at the patterns worth focusing on next.",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Last result — only appears when there's something to show.
                reviewLastResultRow
            }
            .padding(20)
        }
        .navigationDestination(isPresented: $showLatest) {
            if let analysis = latestAnalysis {
                PresenceV2InsightView(analysis: analysis)
            }
        }
        .refreshable {
            await loadLatest()
        }
        .task {
            await loadLatest()
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @MainActor
    private func loadLatest() async {
        guard !PresenceV2BackendConfig.analyzeURLString.isEmpty else { return }
        isLoadingLatest = true
        let result = await PresenceV2BackendClient.shared.fetchLatest()
        if case .success(let analysis) = result {
            latestAnalysis = analysis
        }
        isLoadingLatest = false
    }

    @ViewBuilder
    private var reviewLastResultRow: some View {
        if isLoadingLatest {
            HStack(spacing: 12) {
                ProgressView().tint(theme.accentSuccess).scaleEffect(0.8)
                Text("Looking for recent sessions...")
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.border.opacity(0.6), lineWidth: 1))

        } else if let analysis = latestAnalysis {
            Button { showLatest = true } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last result")
                            .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                            .foregroundStyle(theme.accentSuccess)
                            .textCase(.uppercase)
                            .tracking(0.7)
                        Text(analysis.summary.headline)
                            .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accentStrong)
                }
                .padding(18)
                .background(theme.accentSuccess.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.accentSuccess.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)

        } else {
            // No stored session yet — keep the home clean rather than showing a placeholder.
            EmptyView()
        }
    }

    // The single up-front choice: Just me vs With my partner. Switching swaps which
    // mode's actions are visible, so only one path competes for attention at a time.
    private var audienceToggle: some View {
        HStack(spacing: 0) {
            ForEach(HomeAudience.allCases) { option in
                let selected = option == audience
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { audience = option }
                } label: {
                    Text(option.label)
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selected ? theme.primaryText : theme.secondaryText)
                        .background(
                            selected ? Color.white.opacity(0.95) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    // One-line orientation for the selected mode.
    private func modeDescriptor(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: theme.bodyDesign))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // Compact, lower-weight row for secondary (couples) actions — establishes a clear
    // hierarchy beneath the primary solo card.
    private func secondaryActionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.accentStrong)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(subtitle)
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border.opacity(0.7), lineWidth: 1)
        )
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
    // Shown when speech capture returns empty — explicit fallback, no silent substitution
    @State private var manualEntrySlot: PartnerSlot?
    @State private var manualEntryText = ""
    @FocusState private var manualEntryFocused: Bool

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
                    Text("\"\(capture.transcript)\"")
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Tap the mic icon again when they're done.")
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)

            } else if manualEntrySlot == slot {
                // Speech returned empty — show explicit text entry
                VStack(alignment: .leading, spacing: 10) {
                    Text("Couldn't catch that. Type it instead.")
                        .font(.system(.footnote, design: theme.bodyDesign))
                        .foregroundStyle(theme.accentWarm)

                    TextField("What would make this feel like a good conversation?", text: $manualEntryText, axis: .vertical)
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .focused($manualEntryFocused)
                        .submitLabel(.done)
                        .onSubmit { commitManualEntry() }
                        .padding(12)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(theme.primaryText)

                    Button {
                        commitManualEntry()
                    } label: {
                        Text("Use this")
                            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.accentSuccess.opacity(manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 0.9))
                    )
                    .foregroundStyle(Color.white)
                    .disabled(manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

            } else if let response {
                Text("\"\(response)\"")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Captured.")
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

            if spokenText.isEmpty {
                // Speech came back empty — ask them to type it instead of silently substituting
                capture.stop()
                recordingPartner = nil
                manualEntrySlot = slot
                manualEntryText = ""
                manualEntryFocused = true
            } else {
                switch slot {
                case .partnerOne: partnerOneResponse = spokenText
                case .partnerTwo: partnerTwoResponse = spokenText
                }
                capture.stop()
                recordingPartner = nil
            }
            return
        }

        guard recordingPartner == nil else { return }
        manualEntrySlot = nil
        recordingPartner = slot

        Task {
            let started = await capture.start()
            if !started {
                recordingPartner = nil
            }
        }
    }

    private func commitManualEntry() {
        let text = manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let slot = manualEntrySlot else { return }
        switch slot {
        case .partnerOne: partnerOneResponse = text
        case .partnerTwo: partnerTwoResponse = text
        }
        manualEntrySlot = nil
        manualEntryText = ""
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
                        Text("\"\(monitor.transcript)\"")
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
                    conversationAudioURL: monitor.recordedFileURL,
                    deviceTranscript: monitor.transcript
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
            case .failure(let error):
                self.errorMessage = PresenceV2BackendClient.userMessage(for: error)
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
    @State private var feedbackOutcome: String?   // "yes" | "somewhat" | "no"
    @State private var showDetails = false

    private var theme: PresenceTheme {
        themeStore.current
    }

    // Shows where this analysis came from so the user can tell real model output
    // from the on-device demo, and whether metrics were measured or estimated.
    @ViewBuilder
    private var sourceBanner: some View {
        let demo = analysis.isDemo
        let accent = demo ? theme.accentWarm : theme.accentSuccess
        let icon = demo ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
        let modelName = analysis.model ?? "your local model"
        let title = demo ? "Demo analysis" : "Analyzed by " + modelName
        let measuredDetail = analysis.metricsAreMeasured
            ? "Word balance & interruptions were measured from speaker separation."
            : "Word balance & interruptions were estimated by the model — enable diarization for measured values."
        let detail = demo
            ? (analysis.note ?? "Showing local demo data, not your conversation.")
            : measuredDetail

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                if let confidence = analysis.confidence {
                    Text(confidence.capitalized + " confidence")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.12), in: Capsule())
                }
            }

            Text(detail)
                .font(.system(.footnote, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.22), lineWidth: 1))
    }

    // Numbers + transcript, demoted into one collapsed "details" disclosure so the
    // review leads with the human payoff (insight, quoted moments, next steps) rather
    // than a metrics dashboard. The quoted moments — not the numbers — are the point.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
            } label: {
                HStack {
                    Text("Details & transcript")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accentStrong)
                }
            }
            .buttonStyle(.plain)

            if showDetails {
                metricRow

                if let transcript = analysis.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What Presence heard")
                            .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(transcript)
                            .font(.system(.subheadline, design: theme.bodyDesign))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.border.opacity(0.84), lineWidth: 1))
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

                    if !analysis.summary.subheadline.isEmpty {
                        Text(analysis.summary.subheadline)
                            .font(.system(.body, design: theme.bodyDesign))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("\(formattedDuration) listened • analyzed against your goal for the conversation")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }

                // Lead with the human payoff: the goal, the quoted moments, the next steps.
                sourceBanner
                successDefinitionPanel
                keyMomentsSection
                unmetNeedsSection
                nextTimeSection
                usefulnessSection
                // Numbers and transcript demoted into a collapsed details section.
                detailsSection
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // Shows each person's original words alongside the LLM's synthesis —
    // the mirror: what they said vs. what Presence heard across both of them.
    private var successDefinitionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What success looked like for each of you")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                personDefinitionRow(label: "You", text: analysis.successDefinition.participantOne)
                personDefinitionRow(label: "Your partner", text: analysis.successDefinition.participantTwo)
            }

            Divider()
                .overlay(theme.border.opacity(0.5))

            VStack(alignment: .leading, spacing: 6) {
                Text("What Presence heard across both")
                    .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                    .foregroundStyle(theme.accentSuccess)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Text(analysis.successDefinition.shared)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.medium))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func personDefinitionRow(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("\"\(text)\"")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            Text("What each person needed, but didn't get")
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
            Text("Here's what to try next time")
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
        let accent: Color
        switch moment.type {
        case .positive: accent = theme.accentSuccess
        case .negative: accent = theme.accentWarm
        case .neutral:  accent = theme.accentStrong
        }
        let tint = accent.opacity(0.08)

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

                Text("\"\(moment.quote)\"")
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

    // North-star metric: did this help you understand each other better?
    private var usefulnessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("One last thing")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            Text("Did this help you understand each other better?")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)

            if let outcome = feedbackOutcome {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accentSuccess)
                    Text(outcome == "yes" ? "Glad it helped." : outcome == "somewhat" ? "Thanks — we'll keep improving." : "Noted. That feedback matters.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                HStack(spacing: 10) {
                    feedbackButton(label: "Yes", outcome: "yes", color: theme.accentSuccess)
                    feedbackButton(label: "Somewhat", outcome: "somewhat", color: theme.accentStrong)
                    feedbackButton(label: "Not really", outcome: "no", color: theme.accentWarm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func feedbackButton(label: String, outcome: String, color: Color) -> some View {
        Button {
            feedbackOutcome = outcome
            Task {
                await PresenceV2BackendClient.shared.submitFeedback(
                    sessionID: analysis.sessionID,
                    outcome: outcome,
                    model: analysis.model,
                    confidence: analysis.confidence
                )
            }
        } label: {
            Text(label)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
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

                if !isLoading && (insight.sessionCount ?? 999) < 2 {
                    firstSessionState
                } else {
                    heroRecommendation
                    whyThisMattersSection
                    patternsSection
                    improvingSection
                    workOnListSection
                }
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
            case .failure(let error):
                errorMessage = PresenceV2BackendClient.userMessage(for: error)
                insight = .mock
            }
            isLoading = false
        }
    }

    private var firstSessionState: some View {
        let count = insight.sessionCount ?? 0
        let plural = count == 1 ? "" : "s"
        return VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.accentSuccess.opacity(0.7))

            Text("Not enough conversations yet.")
                .font(.system(size: 22, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("Presence builds this view from repeated conversations. Come back after two or three sessions and it will surface what actually tends to happen between the two of you — not a demo.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("You have \(count) conversation\(plural) recorded.")
                .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentSuccess)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
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
            sectionTitle("What's improving")

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

        init(title: String, summary: String, frequencyLabel: String, contextLabel: String) {
            self.title = title
            self.summary = summary
            self.frequencyLabel = frequencyLabel
            self.contextLabel = contextLabel
        }

        // Tolerate a thin model response: missing fields fall back instead of failing.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = (try? c.decode(String.self, forKey: .title)) ?? "Here's what's worth focusing on next."
            summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
            frequencyLabel = (try? c.decode(String.self, forKey: .frequencyLabel)) ?? ""
            contextLabel = (try? c.decode(String.self, forKey: .contextLabel)) ?? ""
        }
    }

    struct InsightItem: Decodable, Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    let relationshipID: String?
    let timeWindow: String?
    let sessionCount: Int?
    let primaryFocus: PrimaryFocus
    let whyThisMatters: [InsightItem]
    let relationshipPatterns: [InsightItem]
    let improving: [InsightItem]
    let workOnAreas: [InsightItem]

    enum CodingKeys: String, CodingKey {
        case relationshipID = "relationship_id"
        case timeWindow = "time_window"
        case sessionCount = "session_count"
        case primaryFocus = "primary_focus"
        case whyThisMatters = "why_this_matters"
        case relationshipPatterns = "relationship_patterns"
        case improving
        case workOnAreas = "work_on_areas"
    }

    // Degrade gracefully if a local model omits sections, rather than collapsing
    // the whole longitudinal view to demo data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relationshipID = try? c.decode(String.self, forKey: .relationshipID)
        timeWindow = try? c.decode(String.self, forKey: .timeWindow)
        sessionCount = try? c.decode(Int.self, forKey: .sessionCount)
        primaryFocus = (try? c.decode(PrimaryFocus.self, forKey: .primaryFocus))
            ?? PresenceV2WorkOnResponse.mock.primaryFocus
        whyThisMatters = (try? c.decode([InsightItem].self, forKey: .whyThisMatters)) ?? []
        relationshipPatterns = (try? c.decode([InsightItem].self, forKey: .relationshipPatterns)) ?? []
        improving = (try? c.decode([InsightItem].self, forKey: .improving)) ?? []
        workOnAreas = (try? c.decode([InsightItem].self, forKey: .workOnAreas)) ?? []
    }

    static let mock = PresenceV2WorkOnResponse(
        relationshipID: nil,
        timeWindow: "90d",
        sessionCount: nil,
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
        sessionCount: Int?,
        primaryFocus: PrimaryFocus,
        whyThisMatters: [InsightItem],
        relationshipPatterns: [InsightItem],
        improving: [InsightItem],
        workOnAreas: [InsightItem]
    ) {
        self.relationshipID = relationshipID
        self.timeWindow = timeWindow
        self.sessionCount = sessionCount
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
    // Live on-device transcript — used by the backend as a fallback when
    // server-side Whisper isn't installed, so analysis still works.
    var deviceTranscript: String = ""
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

        enum CodingKeys: String, CodingKey {
            case participantOne = "participant_one"
            case participantTwo = "participant_two"
            case shared
        }
    }

    struct Metrics: Decodable {
        struct WordBalance: Decodable {
            let participantOnePercent: Int
            let participantTwoPercent: Int
            let label: String

            enum CodingKeys: String, CodingKey {
                case participantOnePercent = "participant_one_percent"
                case participantTwoPercent = "participant_two_percent"
                case label
            }
        }

        struct Interruptions: Decodable {
            let total: Int
            let participantOne: Int
            let participantTwo: Int
            let label: String

            enum CodingKeys: String, CodingKey {
                case total
                case participantOne = "participant_one"
                case participantTwo = "participant_two"
                case label
            }
        }

        struct ConnectionScore: Decodable {
            let score: Int
            let deltaLabel: String

            enum CodingKeys: String, CodingKey {
                case score
                case deltaLabel = "delta_label"
            }
        }

        struct RepairAttempts: Decodable {
            let total: Int
            let label: String
        }

        let wordBalance: WordBalance
        let interruptions: Interruptions
        let connectionScore: ConnectionScore
        let repairAttempts: RepairAttempts

        enum CodingKeys: String, CodingKey {
            case wordBalance    = "word_balance"
            case interruptions
            case connectionScore = "connection_score"
            case repairAttempts  = "repair_attempts"
        }
    }

    struct KeyMoment: Decodable, Identifiable {
        enum MomentType: String, Decodable {
            case positive
            case negative
            case neutral
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
            self.timestampMs = (try? container.decode(Int.self, forKey: .timestampMs)) ?? 0
            // The backend contract allows "neutral"; tolerate any unknown value
            // rather than failing the whole response decode.
            let rawType = (try? container.decode(String.self, forKey: .type)) ?? "neutral"
            self.type = MomentType(rawValue: rawType) ?? .neutral
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

    // Provenance — lets the UI show whether this is real Ollama output or demo,
    // and whether metrics were measured (diarization) vs estimated by the model.
    struct MetricsSource: Decodable {
        let wordBalance: String?     // "computed" | "estimated"
        let interruptions: String?

        enum CodingKeys: String, CodingKey {
            case wordBalance = "word_balance"
            case interruptions
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

    // Optional provenance / debug fields (absent in older payloads → nil).
    let model: String?
    let confidence: String?
    let diarized: Bool?
    let metricsSource: MetricsSource?
    let note: String?
    let transcript: String?

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
        case model
        case confidence
        case diarized
        case metricsSource = "metrics_source"
        case note
        case transcript
    }

    /// True when this came from the local demo/mock path rather than a live model.
    var isDemo: Bool {
        (model == nil) || (model == "demo") || (model == "mock") || (note != nil)
    }

    /// Human label for where metrics came from.
    var metricsAreMeasured: Bool {
        diarized == true || metricsSource?.wordBalance == "computed"
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
                .init(timestampMs: 190000, type: .negative, title: "Tension rose", quote: "Yeah, but that's not what I meant.", speaker: "You", explanation: "This shifted the conversation from impact to intent, which made your partner feel less met in the emotional part."),
                .init(timestampMs: 525000, type: .positive, title: "Connection improved", quote: "I can see why that felt lonely.", speaker: "You", explanation: "This was the first moment the feeling landed before the problem got solved, and the conversation softened immediately."),
                .init(timestampMs: 680000, type: .positive, title: "You got back on track", quote: "What I actually need is to feel like we're on the same side.", speaker: "Your partner", explanation: "Once the underlying need was named directly, the conversation stopped circling and became more collaborative.")
            ],
            unmetNeeds: [
                .init(person: "You", need: "Reassurance that the conversation wasn't becoming a character judgment."),
                .init(person: "Your partner", need: "A clearer sign that the emotional part landed before the problem-solving started.")
            ],
            nextTime: [
                .init(person: "For you", tryNext: "Before explaining your intent, reflect back the feeling you think you heard in one sentence."),
                .init(person: "For your partner", tryNext: "Name the underlying need earlier, before the conversation gets pulled into logistics.")
            ],
            durationSeconds: submission.durationSeconds,
            model: "demo",
            confidence: "low",
            diarized: false,
            note: "On-device demo analysis — the server wasn't reachable, so this isn't from your conversation."
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
        durationSeconds: Int,
        model: String? = nil,
        confidence: String? = nil,
        diarized: Bool? = nil,
        metricsSource: MetricsSource? = nil,
        note: String? = nil,
        transcript: String? = nil
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
        self.model = model
        self.confidence = confidence
        self.diarized = diarized
        self.metricsSource = metricsSource
        self.note = note
        self.transcript = transcript
    }
}

private actor PresenceV2BackendClient {
    static let shared = PresenceV2BackendClient()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // The first Ollama call after a cold load can take a while, so we give
    // requests a generous timeout rather than the 60s default.
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 180
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    // Retry only transient transport errors. analyze is keyed by session_id with
    // INSERT OR REPLACE server-side, so retries are idempotent.
    private func withRetry<T>(attempts: Int = 2, _ op: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<max(1, attempts) {
            do {
                return try await op()
            } catch let error as URLError where
                [.timedOut, .networkConnectionLost, .cannotConnectToHost].contains(error.code) {
                lastError = error
                if attempt < attempts - 1 { try? await Task.sleep(for: .seconds(1)) }
            }
        }
        throw lastError ?? BackendError.badResponse
    }

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
            let (data, response) = try await withRetry {
                try await session.upload(for: request, from: body)
            }

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }

            let analysis = try JSONDecoder().decode(PresenceV2AnalysisResponse.self, from: data)
            return .success(analysis)
        } catch {
            print("[Presence] analyze failed:", error)
            return .failure(error)
        }
    }

    // Solo single-user reflection: JSON POST (no audio), text only.
    func reflect(submission: PresenceSoloSubmission) async -> Result<PresenceSoloResponse, Error> {
        let urlString = PresenceV2BackendConfig.reflectURLString
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            return .failure(BackendError.notConfigured)
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload = PresenceSoloRequestBody(
                reflection_id: submission.reflectionID,
                user_id: submission.userID,
                mode: submission.mode,
                text: submission.text,
                quote: submission.quote
            )
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await withRetry { try await session.data(for: request) }
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }
            let reflection = try JSONDecoder().decode(PresenceSoloResponse.self, from: data)
            return .success(reflection)
        } catch {
            print("[Presence] reflect failed:", error)
            return .failure(error)
        }
    }

    func fetchLatest() async -> Result<PresenceV2AnalysisResponse, Error> {
        let latest = PresenceV2BackendConfig.latestURLString
        guard !latest.isEmpty, let url = URL(string: latest) else {
            return .failure(BackendError.notConfigured)
        }
        do {
            let (data, response) = try await withRetry { try await session.data(from: url) }
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }
            let analysis = try JSONDecoder().decode(PresenceV2AnalysisResponse.self, from: data)
            return .success(analysis)
        } catch {
            return .failure(error)
        }
    }

    func submitFeedback(sessionID: String, outcome: String, model: String?, confidence: String?) async {
        let feedback = PresenceV2BackendConfig.feedbackURLString(sessionID: sessionID)
        guard !feedback.isEmpty, var components = URLComponents(string: feedback) else { return }
        var items = [URLQueryItem(name: "outcome", value: outcome)]
        if let model { items.append(URLQueryItem(name: "model", value: model)) }
        if let confidence { items.append(URLQueryItem(name: "confidence", value: confidence)) }
        components.queryItems = items
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try? await session.data(for: request)
    }

    func fetchWorkOn() async -> Result<PresenceV2WorkOnResponse, Error> {
        let workOnURL = PresenceV2BackendConfig.workOnURLString
        guard !workOnURL.isEmpty, let url = URL(string: workOnURL) else {
            return .failure(BackendError.notConfigured)
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await withRetry { try await session.data(for: request) }

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw BackendError.badResponse
            }

            let workOn = try JSONDecoder().decode(PresenceV2WorkOnResponse.self, from: data)
            return .success(workOn)
        } catch {
            print("[Presence] work-on failed:", error)
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
        if !submission.deviceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendField(name: "device_transcript", value: submission.deviceTranscript)
        }

        let fileData = try Data(contentsOf: audioURL)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"conversation_audio\"; filename=\"conversation.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
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

    /// Maps a backend failure to a message that tells the truth about what happened,
    /// so a transport/decode failure isn't reported as "backend not configured".
    static func userMessage(for error: Error) -> String {
        if let backendError = error as? BackendError {
            switch backendError {
            case .notConfigured:
                return "No backend URL is set, so Presence is showing a local demo for now."
            case .missingAudio:
                return "No audio was captured for this session — showing a local demo."
            case .badResponse:
                return "The analysis server returned an error. Showing a local demo while it's unavailable."
            }
        }
        if error is DecodingError {
            return "Presence reached the server but couldn't read its response (format mismatch). Showing a local demo."
        }
        let urlError = error as? URLError
        if urlError?.code == .cannotConnectToHost || urlError?.code == .timedOut || urlError?.code == .networkConnectionLost {
            return "Couldn't reach the analysis server. Is it running and on the same network? Showing a local demo."
        }
        return "Couldn't complete analysis (\(error.localizedDescription)). Showing a local demo."
    }
}

@MainActor
private final class PresenceSpeechCaptureManager: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permissionMessage: String?
    @Published var audioLevel: Float = 0   // smoothed RMS 0–1

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
            permissionMessage = "Presence couldn't start the microphone right now."
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
            // Encode to AAC/m4a on write so LAN uploads are a fraction of raw LPCM/CAF.
            // Writing PCM tap buffers to an AAC-configured AVAudioFile converts them.
            let aacSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: Int(format.channelCount),
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            audioFile = try AVAudioFile(forWriting: recordedFileURL, settings: aacSettings)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)
            let rms = Self.rmsLevel(buffer)
            Task { @MainActor in
                // Exponential smoothing so the colour doesn't jitter
                self.audioLevel = self.audioLevel * 0.7 + rms * 0.3
            }
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
            .appendingPathExtension("m4a")
    }

    // Returns a normalised RMS level (0–1) scaled for microphone sensitivity.
    private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        let samples = UnsafeBufferPointer(start: data[0], count: frameCount)
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(frameCount))
        return min(1.0, rms * 12)  // ×12 maps typical speech (≈0.05–0.08 raw) to 0.6–1.0
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
    private let capture = PresenceSpeechCaptureManager()

    // Silence detection
    private var silenceSeconds = 0
    private var lastTranscriptLength = 0

    func start() {
        stop()
        elapsedSeconds = 0
        conversationPulse = 0.78
        silenceSeconds = 0
        lastTranscriptLength = 0
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

                // Silence tracking: if transcript isn't growing and level is low
                let currentLen = self.capture.transcript.count
                let level = self.capture.audioLevel
                if currentLen == self.lastTranscriptLength && level < 0.08 {
                    self.silenceSeconds += 1
                } else {
                    self.silenceSeconds = 0
                    self.lastTranscriptLength = currentLen
                }

                // Target pulse: audio level drives it, silence pulls it down
                let levelPulse = min(1.0, Double(level) * 1.6 + 0.25)
                let silencePenalty: Double = self.silenceSeconds > 5 ? -0.3 : 0
                let target = max(0.15, min(1.0, levelPulse + silencePenalty))

                // Exponential smoothing so colour transitions feel intentional
                self.conversationPulse = self.conversationPulse * 0.82 + target * 0.18
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

// MARK: - Solo (single-user) experience
// Text-first, no recording, no partner required. See docs/v2-solo-experience.md.

private enum PresenceSoloIdentity {
    private static let key = "presence.solo.userID"
    /// Anonymous, persisted per-device id — the seed of per-user relational memory.
    static var userID: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

private enum PresenceSoloIntent: String, CaseIterable, Identifiable {
    case decode, prep, reflect
    var id: String { rawValue }

    var label: String {
        switch self {
        case .decode: return "Decode"
        case .prep: return "Prep"
        case .reflect: return "Reflect"
        }
    }

    var headline: String {
        switch self {
        case .decode: return "What did they mean?"
        case .prep: return "Help me go in well."
        case .reflect: return "Help me process this."
        }
    }

    var detail: String {
        switch self {
        case .decode: return "Something they said landed wrong, or you're not sure how to respond."
        case .prep: return "There's a conversation coming up and you want to start it gently."
        case .reflect: return "Something just happened and you want to make sense of it."
        }
    }

    var contextPrompt: String {
        switch self {
        case .decode: return "What was going on?"
        case .prep: return "What do you want to talk about?"
        case .reflect: return "What happened?"
        }
    }

    var needsQuote: Bool { self == .decode }
}

private struct PresenceSoloRequestBody: Encodable {
    let reflection_id: String
    let user_id: String
    let mode: String
    let text: String
    let quote: String?
}

private struct PresenceSoloSubmission {
    let reflectionID: String
    let userID: String
    let mode: String
    let text: String
    let quote: String?
}

private struct PresenceSoloResponse: Decodable {
    struct Summary: Decodable { let headline: String }
    struct Translation: Decodable {
        let whatTheyMayHaveMeant: String
        let theirPossibleNeed: String
        enum CodingKeys: String, CodingKey {
            case whatTheyMayHaveMeant = "what_they_may_have_meant"
            case theirPossibleNeed = "their_possible_need"
        }
    }

    let reflectionID: String
    let status: String
    let mode: String
    let summary: Summary
    let translation: Translation
    let yourPart: String
    let suggestedNext: String
    let reframe: String?
    let confidence: String?
    let model: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case reflectionID = "reflection_id"
        case status, mode, summary, translation
        case yourPart = "your_part"
        case suggestedNext = "suggested_next"
        case reframe, confidence, model, note
    }

    var isDemo: Bool { model == nil || model == "demo" || note != nil }

    init(reflectionID: String, status: String, mode: String, summary: Summary,
         translation: Translation, yourPart: String, suggestedNext: String,
         reframe: String?, confidence: String?, model: String?, note: String?) {
        self.reflectionID = reflectionID
        self.status = status
        self.mode = mode
        self.summary = summary
        self.translation = translation
        self.yourPart = yourPart
        self.suggestedNext = suggestedNext
        self.reframe = reframe
        self.confidence = confidence
        self.model = model
        self.note = note
    }

    /// On-device fallback when the server isn't reachable — clearly labeled as demo.
    static func mock(reflectionID: String, mode: String) -> PresenceSoloResponse {
        PresenceSoloResponse(
            reflectionID: reflectionID,
            status: "completed",
            mode: mode,
            summary: Summary(headline: "Underneath the sharp words may be a bid for reassurance."),
            translation: Translation(
                whatTheyMayHaveMeant: "It may have been less about the plan and more about feeling like they were carrying it alone.",
                theirPossibleNeed: "To feel that you're on the same side."
            ),
            yourPart: "It's worth noticing whether you moved to fix the logistics before the feeling had landed.",
            suggestedNext: "Try: \"It sounds like you felt alone in this — did I get that right?\" before anything about the plan.",
            reframe: "This reads less like criticism of you and more like a reach for partnership.",
            confidence: "low",
            model: "demo",
            note: "On-device demo — the server wasn't reachable, so this isn't from your input."
        )
    }
}

private struct PresenceSoloInputView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @StateObject private var capture = PresenceSpeechCaptureManager()
    @State private var intent: PresenceSoloIntent = .decode
    @State private var quote = ""
    @State private var context = ""
    @State private var isDictating = false
    @State private var showProcessing = false
    @FocusState private var focused: Field?

    private enum Field { case quote, context }

    private var theme: PresenceTheme { themeStore.current }

    private var canSubmit: Bool {
        let hasContext = !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasQuote = !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return intent.needsQuote ? (hasQuote || hasContext) : hasContext
    }

    private var submission: PresenceSoloSubmission {
        PresenceSoloSubmission(
            reflectionID: UUID().uuidString,
            userID: PresenceSoloIdentity.userID,
            mode: intent.rawValue,
            text: context.trimmingCharacters(in: .whitespacesAndNewlines),
            quote: intent.needsQuote ? quote.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                intentPicker
                if intent.needsQuote { quoteField }
                contextField
                privacyNote
                if let permissionMessage = capture.permissionMessage {
                    Text(permissionMessage)
                        .font(.system(.footnote, design: theme.bodyDesign))
                        .foregroundStyle(theme.accentWarm)
                        .fixedSize(horizontal: false, vertical: true)
                }
                startButton
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Just you")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showProcessing) {
            PresenceSoloProcessingView(submission: submission)
        }
        .onChange(of: capture.transcript) { newValue in
            // Mirror on-device dictation into the context field; audio never leaves the phone.
            if isDictating { context = newValue }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(intent.headline)
                .font(.system(size: 30, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)
            Text(intent.detail)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var intentPicker: some View {
        HStack(spacing: 10) {
            ForEach(PresenceSoloIntent.allCases) { option in
                let selected = option == intent
                Button {
                    intent = option
                } label: {
                    Text(option.label)
                        .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            (selected ? theme.accentSuccess.opacity(0.16) : Color.white.opacity(0.6)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke((selected ? theme.accentSuccess : theme.border).opacity(selected ? 0.5 : 0.7), lineWidth: 1)
                        )
                        .foregroundStyle(selected ? theme.accentStrong : theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quoteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("What they said")
            TextField("\"Fine, do whatever you want.\"", text: $quote, axis: .vertical)
                .font(.system(.body, design: theme.bodyDesign))
                .focused($focused, equals: .quote)
                .padding(12)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(theme.primaryText)
        }
    }

    private var contextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                fieldLabel(intent.contextPrompt)
                Spacer()
                Button {
                    toggleDictation()
                } label: {
                    Image(systemName: isDictating ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isDictating ? theme.accentWarm : theme.accentSuccess)
                }
                .buttonStyle(.plain)
            }
            TextField("Type or tap the mic to speak…", text: $context, axis: .vertical)
                .font(.system(.body, design: theme.bodyDesign))
                .focused($focused, equals: .context)
                .frame(minHeight: 90, alignment: .topLeading)
                .padding(12)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(theme.primaryText)
            if isDictating {
                Text("Listening… tap the mic again when you're done.")
                    .font(.system(.footnote, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var privacyNote: some View {
        Label("Private — analyzed as text. No audio leaves your phone.", systemImage: "lock.fill")
            .font(.system(.footnote, design: theme.bodyDesign))
            .foregroundStyle(theme.secondaryText)
    }

    private var startButton: some View {
        Button {
            if isDictating { toggleDictation() }
            showProcessing = true
        } label: {
            Text("Reflect")
                .font(.system(.headline, design: theme.bodyDesign))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(PresenceV2PrimaryButtonStyle(theme: theme))
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
            .foregroundStyle(theme.accentSuccess)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private func toggleDictation() {
        if isDictating {
            capture.stop()
            isDictating = false
        } else {
            focused = nil
            isDictating = true
            Task {
                let ok = await capture.start()
                if !ok { isDictating = false }
            }
        }
    }
}

private struct PresenceSoloProcessingView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let submission: PresenceSoloSubmission
    @State private var reflection: PresenceSoloResponse?
    @State private var showResult = false
    @State private var errorMessage: String?

    private var theme: PresenceTheme { themeStore.current }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.accentSuccess)
                .scaleEffect(1.25)
            Text("Thinking it through")
                .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)
            Text("Reading what you wrote and looking for what may be underneath it.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showResult) {
            if let reflection {
                PresenceSoloResultView(reflection: reflection)
            }
        }
        .task {
            guard !showResult else { return }
            let result = await PresenceV2BackendClient.shared.reflect(submission: submission)
            switch result {
            case .success(let value):
                reflection = value
            case .failure(let error):
                errorMessage = PresenceV2BackendClient.userMessage(for: error)
                reflection = PresenceSoloResponse.mock(reflectionID: submission.reflectionID, mode: submission.mode)
            }
            try? await Task.sleep(for: .seconds(0.6))
            showResult = true
        }
    }
}

private struct PresenceSoloResultView: View {
    @EnvironmentObject private var themeStore: ThemeStore
    let reflection: PresenceSoloResponse
    @State private var feedbackOutcome: String?

    private var theme: PresenceTheme { themeStore.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A way to see it")
                        .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
                        .foregroundStyle(theme.accentSuccess)
                        .textCase(.uppercase)
                        .tracking(0.7)
                    Text(reflection.summary.headline)
                        .font(.system(size: 28, weight: .bold, design: theme.displayDesign))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sourceBanner
                translationCard
                if !reflection.yourPart.isEmpty { yourPartCard }
                suggestedNextCard
                if let reframe = reflection.reframe, !reframe.isEmpty { reframeCard(reframe) }
                usefulnessSection
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var sourceBanner: some View {
        let demo = reflection.isDemo
        let accent = demo ? theme.accentWarm : theme.accentSuccess
        let icon = demo ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
        let title = demo ? "Demo reflection" : "Reflection by " + (reflection.model ?? "your local model")
        let detail = demo
            ? (reflection.note ?? "Showing local demo data, not your input.")
            : "Generated from your text. Nothing was recorded."
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            Text(detail)
                .font(.system(.footnote, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.22), lineWidth: 1))
    }

    private var translationCard: some View {
        soloCard {
            cardTitle("What they may have meant")
            cardBody(reflection.translation.whatTheyMayHaveMeant)
            Divider().overlay(theme.border.opacity(0.5)).padding(.vertical, 2)
            cardEyebrow("What they might need")
            cardBody(reflection.translation.theirPossibleNeed)
        }
    }

    private var yourPartCard: some View {
        soloCard {
            cardTitle("A gentle thing to notice")
            cardBody(reflection.yourPart)
        }
    }

    private var suggestedNextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardEyebrow("Something to try")
            Text(reflection.suggestedNext)
                .font(.system(.body, design: theme.bodyDesign).weight(.medium))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(theme.accentSuccess.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.accentSuccess.opacity(0.28), lineWidth: 1))
    }

    private func reframeCard(_ text: String) -> some View {
        soloCard {
            cardTitle("Another angle")
            cardBody(text)
        }
    }

    private var usefulnessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Did this help?")
            if let outcome = feedbackOutcome {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accentSuccess)
                    Text(outcome == "yes" ? "Glad it helped." : outcome == "somewhat" ? "Thanks — we'll keep improving." : "Noted. That matters.")
                        .font(.system(.subheadline, design: theme.bodyDesign))
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                HStack(spacing: 10) {
                    feedbackButton(label: "Yes", outcome: "yes", color: theme.accentSuccess)
                    feedbackButton(label: "Somewhat", outcome: "somewhat", color: theme.accentStrong)
                    feedbackButton(label: "Not really", outcome: "no", color: theme.accentWarm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.border.opacity(0.84), lineWidth: 1))
    }

    private func feedbackButton(label: String, outcome: String, color: Color) -> some View {
        Button {
            feedbackOutcome = outcome
            Task {
                await PresenceV2BackendClient.shared.submitFeedback(
                    sessionID: reflection.reflectionID,
                    outcome: outcome,
                    model: reflection.model,
                    confidence: reflection.confidence
                )
            }
        } label: {
            Text(label)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func soloCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.border.opacity(0.84), lineWidth: 1))
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text).font(.system(.headline, design: theme.bodyDesign)).foregroundStyle(theme.primaryText)
    }
    private func cardEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: theme.bodyDesign).weight(.bold))
            .foregroundStyle(theme.accentSuccess)
            .textCase(.uppercase)
            .tracking(0.7)
    }
    private func cardBody(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: theme.bodyDesign))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
