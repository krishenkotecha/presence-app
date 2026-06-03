import Foundation

enum CoachEngine {
    static func makeSession(
        from activeSession: ActiveConversation,
        ratings: ConversationRatings,
        priorSessions: [ConversationSession]
    ) -> ConversationSession {
        let scenario = activeSession.scenario
        let adjustedSuggestion = adjustedSuggestion(
            defaultSuggestion: scenario.defaultSuggestion,
            goal: activeSession.setup.goal,
            productive: ratings.productive,
            alignment: ratings.alignment
        )

        let adjustedHeadline = adjustedHeadline(
            base: scenario.headline,
            productive: ratings.productive,
            alignment: ratings.alignment
        )

        let adjustedHowYouShowedUp = adjustedHowYouShowedUp(
            base: scenario.howYouShowedUp,
            goal: activeSession.setup.goal,
            priorSessions: priorSessions
        )

        let reflection = ConversationReflection(
            headline: adjustedHeadline,
            patternTitle: scenario.patternTitle,
            whatWentWell: scenario.whatWentWell,
            whereItGotHarder: scenario.whereItGotHarder,
            howYouShowedUp: adjustedHowYouShowedUp,
            nextTimeSuggestion: adjustedSuggestion,
            keyMoments: scenario.keyMoments
        )

        return ConversationSession(
            id: activeSession.id,
            startedAt: activeSession.startedAt,
            endedAt: activeSession.startedAt.addingTimeInterval(Double(activeSession.durationMinutes) * 60.0),
            durationMinutes: activeSession.durationMinutes,
            setup: activeSession.setup,
            transcript: scenario.transcript,
            reflection: reflection,
            ratings: ratings,
            sourceLabel: scenario.sourceLabel
        )
    }

    private static func adjustedSuggestion(
        defaultSuggestion: String,
        goal: ConversationGoal?,
        productive: Int,
        alignment: Int
    ) -> String {
        if productive <= 2 || alignment <= 2 {
            return "When you feel the conversation speeding up, pause before your next point and name what you think the other person is actually feeling."
        }

        switch goal {
        case .beUnderstood:
            return "Before making your case, reflect back the core concern in one sentence so your point lands after they feel heard."
        case .stayCalm:
            return "When the tone tightens, slow your pace and shorten your next sentence instead of adding more explanation."
        case .beHonest:
            return "State the hardest sentence a little earlier, before you soften it with qualifiers or logistics."
        case .resolveSomething:
            return "Separate the emotional issue from the decision itself, then solve only the part you both agree is on the table."
        case .feelCloser:
            return "Lead with impact before intent so the repair lands as connection instead of clarification."
        case .setBoundary:
            return "Name the limit clearly in one calm sentence before you explain why it matters."
        case .beClear:
            return "State the actual decision or ask in plain language before discussing all the supporting details."
        case .other:
            return defaultSuggestion
        case .none:
            return defaultSuggestion
        }
    }

    private static func adjustedHeadline(base: String, productive: Int, alignment: Int) -> String {
        if productive >= 4 && alignment >= 4 {
            return "\(base) You stayed closer to the conversation you wanted to have."
        }

        if productive <= 2 || alignment <= 2 {
            return "\(base) This one seems to have drifted away from how you wanted to show up."
        }

        return base
    }

    private static func adjustedHowYouShowedUp(
        base: String,
        goal: ConversationGoal?,
        priorSessions: [ConversationSession]
    ) -> String {
        guard let goal else { return base }

        let recurringNote: String
        if priorSessions.contains(where: { $0.reflection.patternTitle == "Explanation mode" }) {
            recurringNote = " This also matches a pattern that has shown up in a few recent conversations."
        } else {
            recurringNote = ""
        }

        switch goal {
        case .beUnderstood:
            return "\(base) You seemed most effective once you slowed down enough to respond to what was being felt, not just what was being said.\(recurringNote)"
        case .stayCalm:
            return "\(base) The moments that felt best were the moments where your pace stayed measured.\(recurringNote)"
        case .beHonest:
            return "\(base) You seemed to know what mattered, but you approached it carefully.\(recurringNote)"
        case .resolveSomething:
            return "\(base) You kept trying to move things forward, even when the emotional layer was still active.\(recurringNote)"
        case .feelCloser:
            return "\(base) You stayed in the conversation instead of pulling away, which matters.\(recurringNote)"
        case .setBoundary:
            return "\(base) You were closest to yourself when your language was shortest and clearest.\(recurringNote)"
        case .beClear:
            return "\(base) The conversation improved whenever your main point became easier to track.\(recurringNote)"
        case .other:
            return "\(base)\(recurringNote)"
        }
    }
}
