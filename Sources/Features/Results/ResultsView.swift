import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    let session: ConversationSession

    private var theme: PresenceTheme {
        themeStore.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                reflectionPrelude
                reflectionNarrative
                keyMomentsTimeline
                transcriptExcerpt
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(InsightBackdrop(theme: theme).ignoresSafeArea())
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var reflectionPrelude: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reflection")
                .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.accentSuccess)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(session.setup.conversationTypeDisplayLabel ?? "Conversation")
                .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
                .foregroundStyle(theme.mutedText)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(session.reflection.headline)
                .font(.system(size: 34, weight: .bold, design: theme.displayDesign))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pattern: \(session.reflection.patternTitle)")
                .font(.system(.title3, design: theme.bodyDesign))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                chip(session.setup.relationshipDisplayLabel ?? "Conversation")
                if let goal = session.goalLabel {
                    chip(goal)
                }
                chip("\(session.durationMinutes) min")
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(theme.accentSuccess)
                .frame(width: 5)
                .padding(.vertical, 20)
                .padding(.leading, 12)
        }
        .shadow(color: theme.accentSuccess.opacity(0.08), radius: 16, x: 0, y: 10)
    }

    private var reflectionNarrative: some View {
        VStack(alignment: .leading, spacing: 26) {
            reflectionPassage(
                title: "What went well",
                text: session.reflection.whatWentWell,
                tint: theme.accentSuccess
            )

            reflectionPassage(
                title: "Where it got harder",
                text: session.reflection.whereItGotHarder,
                tint: theme.accentWarm
            )

            reflectionPassage(
                title: "How you showed up",
                text: session.reflection.howYouShowedUp,
                tint: theme.accentCool
            )

            reflectionPassage(
                title: "One thing to try next time",
                text: session.reflection.nextTimeSuggestion,
                tint: theme.accentStrong,
                emphasize: true
            )
        }
    }

    private var keyMomentsTimeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Key moments")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(session.reflection.keyMoments) { moment in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(theme.accentStrong)
                                .frame(width: 12, height: 12)

                            Rectangle()
                                .fill(theme.accentStrong.opacity(0.18))
                                .frame(width: 2)
                        }
                        .frame(width: 14)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(moment.timeMark)
                                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.accentSuccess)

                            Text(moment.summary)
                                .font(.system(.body, design: theme.bodyDesign))
                                .foregroundStyle(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(theme.border.opacity(0.84), lineWidth: 1)
            )
        }
    }

    private var transcriptExcerpt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcript")
                .font(.system(.headline, design: theme.bodyDesign))
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(session.transcript) { beat in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(beat.speaker == .partner ? theme.transcriptThem : theme.transcriptYou)
                            .frame(width: 10, height: 10)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(beat.speaker.label)
                                .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
                                .foregroundStyle(theme.mutedText)

                            Text(beat.text)
                                .font(.system(.subheadline, design: theme.bodyDesign))
                                .foregroundStyle(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(theme.border.opacity(0.84), lineWidth: 1)
            )
        }
    }

    private func reflectionPassage(title: String, text: String, tint: Color, emphasize: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(tint)
                .frame(width: 6)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(.footnote, design: theme.bodyDesign).weight(.semibold))
                        .foregroundStyle(theme.mutedText)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(text)
                        .font(
                            emphasize
                                ? .system(size: 24, weight: .semibold, design: theme.displayDesign)
                                : .system(.title3, design: theme.bodyDesign)
                        )
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.border.opacity(0.84), lineWidth: 1)
        )
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: theme.bodyDesign).weight(.semibold))
            .foregroundStyle(theme.chipText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.74), in: Capsule())
    }
}
