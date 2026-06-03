import SwiftUI

struct CalibrationView: View {
    let activeSession: ActiveConversation

    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var productive = 4
    @State private var alignment = 3
    @State private var note = ""
    @State private var completedSession: ConversationSession?

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                introCard

                ratingSection(
                    title: "Did this conversation feel productive?",
                    selection: $productive
                )

                ratingSection(
                    title: "Did you show up the way you wanted to?",
                    selection: $alignment
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything important to keep in mind?")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)

                    TextField("Optional note", text: $note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: theme.bodyDesign))
                        .foregroundStyle(theme.primaryText)
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.white.opacity(0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.44), lineWidth: 1)
                        )
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.86), Color.white.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.48), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)

                Button {
                    completedSession = store.completeSession(
                        activeSession: activeSession,
                        ratings: ConversationRatings(
                            productive: productive,
                            alignment: alignment,
                            note: note
                        )
                    )
                } label: {
                    Text("Generate reflection")
                        .font(.system(.headline, design: theme.bodyDesign))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(GenerateButtonStyle(theme: theme))
            }
            .padding(20)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Quick check-in")
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(item: $completedSession) { session in
            ResultsView(session: session)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("After the conversation", systemImage: "sparkles")
                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentSuccess)

            Text("A tiny bit of self-report makes the coaching more personal over time.")
                .font(.system(size: 26, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)

            Text("These ratings become training signals later. For now they help the prototype feel like the real loop.")
                .font(.system(.subheadline, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 6)
    }

    private func ratingSection(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    let isSelected = selection.wrappedValue == value
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(value)")
                                .font(.system(.title3, design: theme.displayDesign).weight(.bold))
                            Text(label(for: value))
                                .font(.system(.caption, design: theme.bodyDesign))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ratingButtonBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isSelected ? theme.accentSuccess.opacity(0.3) : theme.border.opacity(0.84), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? theme.primaryText : theme.chipText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func ratingButtonBackground(isSelected: Bool) -> LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [theme.secondaryButtonBackground.opacity(0.82), theme.accentSuccess.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.78), Color.white.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 1: "Low"
        case 2: "Rough"
        case 3: "Mixed"
        case 4: "Good"
        default: "Strong"
        }
    }
}

private struct GenerateButtonStyle: ButtonStyle {
    let theme: PresenceTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if theme.kind == .sunlit {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [theme.heroStart, theme.heroEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(theme.primaryButtonBackground)
                    }
                }
                .opacity(configuration.isPressed ? 0.84 : 1)
            )
            .foregroundStyle(theme.primaryButtonText)
            .shadow(color: theme.kind == .sunlit ? theme.heroEnd.opacity(0.18) : .clear, radius: 16, x: 0, y: 10)
    }
}
