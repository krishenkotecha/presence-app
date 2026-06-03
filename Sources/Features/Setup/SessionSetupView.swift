import SwiftUI

struct SessionSetupView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var setup = ConversationSetup()
    @State private var visibleStep: SetupStep = .relationship
    @State private var pendingSession: ActiveConversation?
    @State private var customEntryStep: SetupStep?
    @State private var customEntryText = ""
    @FocusState private var isCustomEntryFocused: Bool

    private var theme: PresenceTheme {
        themeStore.current
    }

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: 12)]

    private enum SetupStep: Int, CaseIterable {
        case relationship
        case conversationType
        case goal

        var index: Int { rawValue + 1 }
        var title: String {
            switch self {
            case .relationship: "Who is this with?"
            case .conversationType: "What kind of conversation is this?"
            case .goal: "What do you want from this conversation?"
            }
        }

        var eyebrow: String {
            "Step \(index) of 3"
        }
    }

    private struct SetupAdvice {
        let title: String
        let body: String
    }

    private var currentStep: SetupStep { visibleStep }
    private var canStartNow: Bool { setup.canStart }
    private var isWritingCustomEntry: Bool { customEntryStep == currentStep }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                flowHeader
                currentPrompt
                secondaryActions
                guidanceNote
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(item: $pendingSession) { activeSession in
            RecordingView(activeSession: activeSession)
        }
    }

    private var flowHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                if currentStep != .relationship {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            switch currentStep {
                            case .relationship:
                                break
                            case .conversationType:
                                visibleStep = .relationship
                            case .goal:
                                visibleStep = .conversationType
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.primaryText.opacity(0.82))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.55))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(currentStep.eyebrow)
                    .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
                    .foregroundStyle(theme.accentSuccess)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            HStack(spacing: 10) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? theme.accentSuccess : Color.white.opacity(0.3))
                        .frame(height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(currentStep.title)
                    .font(.system(size: 36, weight: .semibold, design: theme.displayDesign))
                    .foregroundStyle(theme.primaryText)

                Text(headerSupport)
                    .font(.system(.title3, design: theme.bodyDesign))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var currentPrompt: some View {
        switch currentStep {
        case .relationship:
            VStack(alignment: .leading, spacing: 14) {
                optionGrid(
                    selection: setup.relationshipType?.label,
                    options: RelationshipType.allCases.filter { $0 != .other }
                ) { relationship in
                    customEntryStep = nil
                    customEntryText = ""
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        setup.relationshipType = relationship
                        setup.customRelationshipDescription = nil
                        visibleStep = .conversationType
                    }
                }

                if isWritingCustomEntry {
                    customEntryCard(
                        title: "Describe who this is with",
                        prompt: "Ex. Ex-partner, sibling, roommate"
                    )
                }
            }
        case .conversationType:
            VStack(alignment: .leading, spacing: 14) {
                optionGrid(
                    selection: setup.conversationType?.label,
                    options: ConversationType.allCases.filter { $0 != .other }
                ) { type in
                    customEntryStep = nil
                    customEntryText = ""
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        setup.conversationType = type
                        setup.customConversationTypeDescription = nil
                        if let goal = setup.goal, !store.goals(for: type).contains(goal) {
                            setup.goal = nil
                        }
                        visibleStep = .goal
                    }
                }

                if isWritingCustomEntry {
                    customEntryCard(
                        title: "Describe the kind of conversation",
                        prompt: "Ex. Money talk, breakup, parenting issue"
                    )
                }
            }
        case .goal:
            VStack(alignment: .leading, spacing: 14) {
                optionGrid(
                    selection: setup.goal?.label,
                    options: store.goals(for: setup.conversationType)
                ) { goal in
                    customEntryStep = nil
                    customEntryText = ""
                    var completedSetup = setup
                    completedSetup.goal = goal
                    completedSetup.customGoalDescription = nil
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        setup = completedSetup
                        pendingSession = store.startSession(with: completedSetup)
                    }
                }

                if isWritingCustomEntry {
                    customEntryCard(
                        title: "Describe what you want more of",
                        prompt: "Ex. Less blame, more teamwork"
                    )
                }
            }
        }
    }

    private var guidanceNote: some View {
        let advice = advice(for: setup)

        return VStack(alignment: .leading, spacing: 8) {
            Text(advice.title)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)

            Text(advice.body)
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var secondaryActions: some View {
        HStack(spacing: 0) {
            actionRowButton(
                title: isWritingCustomEntry ? "Cancel other" : "Other",
                systemImage: isWritingCustomEntry ? "xmark" : "square.and.pencil"
            ) {
                handleOtherAction()
            }

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1, height: 22)

            actionRowButton(
                title: currentStep == .goal ? "Skip" : "Skip for now",
                systemImage: "arrow.right"
            ) {
                handleSkipAction()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border.opacity(0.8), lineWidth: 1)
        )
    }

    private func optionGrid<Option: Identifiable>(
        selection: String?,
        options: [Option],
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option.ID == String, Option: LabelProviding {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(options) { option in
                GuidedOptionCard(
                    title: option.label,
                    symbolName: option.symbolName,
                    isSelected: option.label == selection,
                    theme: theme
                ) {
                    onSelect(option)
                }
            }
        }
    }

    private var headerSupport: String {
        switch currentStep {
        case .relationship:
            "Pick the relationship first so Presence understands the emotional stakes."
        case .conversationType:
            "Now choose the shape of the conversation."
        case .goal:
            "One last thing: what do you want more of when this is over?"
        }
    }

    private var showsOtherAction: Bool {
        true
    }

    private func handleOtherAction() {
        if isWritingCustomEntry {
            customEntryStep = nil
            customEntryText = ""
            isCustomEntryFocused = false
            return
        }

        switch currentStep {
        case .relationship:
            customEntryText = setup.customRelationshipDescription ?? ""
        case .conversationType:
            customEntryText = setup.customConversationTypeDescription ?? ""
        case .goal:
            customEntryText = setup.customGoalDescription ?? ""
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            customEntryStep = currentStep
        }
        isCustomEntryFocused = true
    }

    private func handleSkipAction() {
        if currentStep == .goal, canStartNow {
            pendingSession = store.startSession(with: setup)
        } else {
            pendingSession = store.startSession(with: ConversationSetup(wasSkipped: true))
        }
    }

    private func commitCustomEntry() {
        let trimmed = customEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentStep {
        case .relationship:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                setup.relationshipType = .other
                setup.customRelationshipDescription = trimmed
                customEntryStep = nil
                visibleStep = .conversationType
            }
        case .conversationType:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                setup.conversationType = .other
                setup.customConversationTypeDescription = trimmed
                customEntryStep = nil
                visibleStep = .goal
            }
        case .goal:
            var completedSetup = setup
            completedSetup.goal = .other
            completedSetup.customGoalDescription = trimmed
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                setup = completedSetup
                customEntryStep = nil
                pendingSession = store.startSession(with: completedSetup)
            }
        }
    }

    private func actionRowButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(theme.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private func customEntryCard(title: String, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentSuccess)

            TextField(prompt, text: $customEntryText)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .focused($isCustomEntryFocused)
                .submitLabel(.continue)
                .onSubmit {
                    commitCustomEntry()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(theme.primaryText)

            Button {
                commitCustomEntry()
            } label: {
                Text("Use this")
                    .font(.system(.subheadline, design: theme.bodyDesign).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.accentSuccess.opacity(customEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 0.95))
            )
            .foregroundStyle(Color.white.opacity(customEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.72 : 1))
            .disabled(customEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.border.opacity(0.82), lineWidth: 1)
        )
    }

    private func advice(for setup: ConversationSetup) -> SetupAdvice {
        switch (setup.relationshipType, setup.conversationType, setup.goal) {
        case (nil, _, _):
            return SetupAdvice(
                title: "Begin with the social stakes",
                body: "A conversation with your partner, your boss, or a friend asks for different kinds of steadiness. Naming the relationship helps the coach read the room."
            )
        case (_, nil, _):
            return SetupAdvice(
                title: "Now name the shape of it",
                body: "Conflict, planning, and repair each have their own rhythm. The same interruption or pause can mean very different things depending on the kind of conversation you’re having."
            )
        case (.some(.partner), .some(.conflict), .some(.beUnderstood)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "In partner conflict, being understood usually depends on whether you slowed down enough before explaining. Expect the reflection to focus on that turning point."
            )
        case (.some(.partner), .some(.repair), _):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Repair tends to go better when the emotional bruise is named before logistics or intent take over. The coach will look for that shift."
            )
        case (_, .some(.planning), _):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Planning often starts practical and then quietly becomes emotional. Presence will pay attention to where logistics turn into fairness, pressure, or appreciation."
            )
        case (_, .some(.vulnerableConversation), _):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Vulnerable conversations depend on pacing. The reflection will likely focus on whether honesty was met with steadiness, curiosity, or quick fixing."
            )
        case (_, _, .some(.stayCalm)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Because calm is the goal, the coach will put extra weight on escalation points, overlap, and moments where the conversation narrowed."
            )
        case (_, _, .some(.beClear)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Because clarity matters here, the reflection will center on whether your real point arrived early enough and stayed visible as the conversation moved."
            )
        case (_, _, .some(.feelCloser)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Because connection is the goal, the coach will look for warmth, acknowledgement, and whether both people stayed emotionally reachable."
            )
        case (_, _, .some(.setBoundary)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "For a boundary conversation, the main question is whether directness stayed calm and intact instead of turning apologetic or sharp."
            )
        case (_, _, .some(.beHonest)):
            return SetupAdvice(
                title: "What Presence will likely watch here",
                body: "Because honesty matters most here, the coach will likely focus on whether you said the thing that actually mattered, not just the safer version of it."
            )
        default:
            return SetupAdvice(
                title: "You can stop here or add one more lens",
                body: "Presence already has enough to guide the session. If you choose a goal too, the reflection will know what success was supposed to feel like."
            )
        }
    }
}

private protocol LabelProviding {
    var label: String { get }
    var symbolName: String { get }
}

extension RelationshipType: LabelProviding {}
extension ConversationType: LabelProviding {}
extension ConversationGoal: LabelProviding {}

private struct GuidedOptionCard: View {
    let title: String
    let symbolName: String
    let isSelected: Bool
    let theme: PresenceTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.white.opacity(0.98), theme.accentSuccess.opacity(0.16)]
                                : [Color.white.opacity(0.7), Color.white.opacity(0.54)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(isSelected ? theme.accentSuccess.opacity(0.3) : theme.border.opacity(0.82), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isSelected ? 0.16 : 0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isSelected ? theme.accentSuccess : Color.white.opacity(0.9))
                                .frame(width: 34, height: 34)

                            Image(systemName: symbolName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : theme.accentSuccess)
                        }

                        Spacer()

                        Circle()
                            .stroke(isSelected ? theme.accentSuccess : theme.border.opacity(0.95), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .fill(isSelected ? theme.accentSuccess : .clear)
                                    .frame(width: 8, height: 8)
                            }
                    }

                    Text(title)
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
                .padding(18)
            }
            .shadow(color: isSelected ? theme.accentSuccess.opacity(0.08) : .clear, radius: 16, x: 0, y: 10)
            .scaleEffect(isSelected ? 0.982 : 1)
        }
        .buttonStyle(.plain)
    }
}
