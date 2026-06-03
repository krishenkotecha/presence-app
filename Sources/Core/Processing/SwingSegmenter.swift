import Foundation

enum ScenarioLibrary {
    static func scenario(for setup: ConversationSetup, existingCount: Int) -> ScenarioTemplate {
        let normalizedType = setup.conversationType ?? .checkIn
        let candidates = templates.filter { $0.setup.conversationType == normalizedType }
        let relationshipMatch = candidates.first { $0.setup.relationshipType == setup.relationshipType }
        let fallback = candidates.first ?? templates[existingCount % templates.count]
        return relationshipMatch ?? fallback
    }

    static func seededSessions(referenceDate: Date = .now) -> [ConversationSession] {
        let presets: [(scenario: ScenarioTemplate, daysAgo: Int, productive: Int, alignment: Int, note: String)] = [
            (planningScenario, 1, 4, 3, "Started as scheduling, turned into fairness."),
            (repairScenario, 4, 4, 4, "Felt a lot better by the end."),
            (vulnerableScenario, 8, 3, 3, "I said most of it, but not as directly as I wanted.")
        ]

        return presets.map { preset in
            let startedAt = Calendar.current.date(byAdding: .day, value: -preset.daysAgo, to: referenceDate) ?? referenceDate
            let active = ActiveConversation(
                id: UUID(),
                setup: preset.scenario.setup,
                scenario: preset.scenario,
                startedAt: startedAt
            )
            return CoachEngine.makeSession(
                from: active,
                ratings: ConversationRatings(
                    productive: preset.productive,
                    alignment: preset.alignment,
                    note: preset.note
                ),
                priorSessions: []
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    private static let templates: [ScenarioTemplate] = [
        checkInScenario,
        conflictScenario,
        repairScenario,
        planningScenario,
        vulnerableScenario,
        decisionScenario
    ]

    private static let checkInScenario = ScenarioTemplate(
        id: "check-in-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .checkIn,
            goal: .feelCloser
        ),
        durationMinutes: 7,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .partner, text: "You’ve felt a little far away the last couple nights. Is everything okay?"),
            TranscriptBeat(offsetSeconds: 6, speaker: .you, text: "I think I’ve just been in my head, but I know I’ve also been harder to reach."),
            TranscriptBeat(offsetSeconds: 12, speaker: .partner, text: "I don’t need you to be upbeat. I just want to know where you are."),
            TranscriptBeat(offsetSeconds: 18, speaker: .you, text: "That helps. I think I’ve been trying to act normal instead of just saying I’m drained."),
            TranscriptBeat(offsetSeconds: 24, speaker: .partner, text: "I can handle drained. I just don’t want to guess.")
        ],
        headline: "A gentle check-in gave you both more clarity than distance.",
        patternTitle: "Careful honesty",
        whatWentWell: "You answered honestly once the conversation opened up, and you let the other person reassure you without changing the subject.",
        whereItGotHarder: "The first few moments were a little guarded, which made the conversation feel more tentative than it needed to.",
        howYouShowedUp: "You started carefully, then became more open once you sensed the conversation was safe.",
        keyMoments: [
            KeyMoment(timeMark: "0:18", summary: "The tone softened once you named feeling drained instead of acting normal."),
            KeyMoment(timeMark: "0:24", summary: "The other person made it clear they wanted honesty more than a polished answer.")
        ],
        defaultSuggestion: "Say the real state you are in a little earlier so the conversation can get to closeness faster."
    )

    private static let conflictScenario = ScenarioTemplate(
        id: "conflict-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .conflict,
            goal: .beUnderstood
        ),
        durationMinutes: 11,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .partner, text: "When I brought up the dinner plans, it felt like you were already annoyed with me."),
            TranscriptBeat(offsetSeconds: 7, speaker: .you, text: "I wasn’t annoyed with you. I’d just had a long day and didn’t want to decide everything again."),
            TranscriptBeat(offsetSeconds: 15, speaker: .partner, text: "I get that, but you went straight into defending yourself instead of hearing me."),
            TranscriptBeat(offsetSeconds: 22, speaker: .you, text: "I know. I just felt blamed the second it came up."),
            TranscriptBeat(offsetSeconds: 30, speaker: .partner, text: "I wasn’t trying to blame you. I wanted you to notice how sharp it sounded."),
            TranscriptBeat(offsetSeconds: 38, speaker: .you, text: "Okay. I can hear that. It probably did sound sharper than I meant.")
        ],
        headline: "This conversation had a real chance to reset once you stopped arguing intent.",
        patternTitle: "Explanation mode",
        whatWentWell: "You stayed in the conversation even after the tone tightened, and you were eventually willing to acknowledge the impact of how you sounded.",
        whereItGotHarder: "Tension rose when the conversation shifted from plans to how the interaction felt. That was the moment where explanation started to crowd out listening.",
        howYouShowedUp: "You moved quickly into clarifying your intent when the other person was still trying to describe their experience.",
        keyMoments: [
            KeyMoment(timeMark: "0:15", summary: "The conversation turned when the focus moved from dinner plans to feeling unheard."),
            KeyMoment(timeMark: "0:38", summary: "The tone softened as soon as you acknowledged impact instead of intent.")
        ],
        defaultSuggestion: "Before explaining what you meant, reflect back what landed for the other person so you are responding to the same conversation."
    )

    private static let repairScenario = ScenarioTemplate(
        id: "repair-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .repair,
            goal: .feelCloser
        ),
        durationMinutes: 9,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .you, text: "I didn’t like how last night ended, and I don’t want us to just move on from it."),
            TranscriptBeat(offsetSeconds: 8, speaker: .partner, text: "Me neither. I still felt pretty shut out this morning."),
            TranscriptBeat(offsetSeconds: 16, speaker: .you, text: "I can see that. I got defensive, and then I went quiet instead of staying with you."),
            TranscriptBeat(offsetSeconds: 24, speaker: .partner, text: "That part mattered more than the original argument."),
            TranscriptBeat(offsetSeconds: 32, speaker: .you, text: "I get why. I want to do that differently next time, because I was still with you even if it didn’t look like it."),
            TranscriptBeat(offsetSeconds: 40, speaker: .partner, text: "Hearing that helps. I think I just needed you to say it.")
        ],
        headline: "This repair worked because you named the rupture instead of pretending it had already passed.",
        patternTitle: "Repair follow-through",
        whatWentWell: "You took responsibility without collapsing into self-criticism, which made it easier for the other person to stay open.",
        whereItGotHarder: "The only sticking point was the temptation to explain what you meant before fully staying with how it felt on the other side.",
        howYouShowedUp: "You were willing to re-enter a hard moment and make the conversation about repair rather than self-defense.",
        keyMoments: [
            KeyMoment(timeMark: "0:16", summary: "Naming defensiveness and shutdown helped the conversation move from blame to repair."),
            KeyMoment(timeMark: "0:40", summary: "Connection returned once you said what had not been said the night before.")
        ],
        defaultSuggestion: "In repair conversations, lead with impact and ownership before adding reassurance or explanation."
    )

    private static let planningScenario = ScenarioTemplate(
        id: "planning-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .planning,
            goal: .resolveSomething
        ),
        durationMinutes: 10,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .partner, text: "Can we figure out the weekend schedule? I feel like it all landed on me again."),
            TranscriptBeat(offsetSeconds: 8, speaker: .you, text: "I thought we already covered most of it, but yeah, let’s sort it out."),
            TranscriptBeat(offsetSeconds: 16, speaker: .partner, text: "That’s kind of the point. We cover the calendar, but not who’s carrying the mental load."),
            TranscriptBeat(offsetSeconds: 24, speaker: .you, text: "Okay, that makes more sense. I was hearing logistics, not fairness."),
            TranscriptBeat(offsetSeconds: 33, speaker: .partner, text: "Exactly. I need us to talk about both."),
            TranscriptBeat(offsetSeconds: 42, speaker: .you, text: "Then let’s separate them. First the schedule, then the part where this has felt uneven.")
        ],
        headline: "You improved the conversation once you recognized it was not only about the calendar.",
        patternTitle: "Logistics first",
        whatWentWell: "Once the real issue surfaced, you adjusted instead of insisting on the narrower version of the conversation.",
        whereItGotHarder: "The conversation got tight when you initially treated an emotional complaint like a scheduling problem.",
        howYouShowedUp: "You were quick to solve the surface issue, but became more effective once you recognized the deeper concern underneath it.",
        keyMoments: [
            KeyMoment(timeMark: "0:16", summary: "The real friction showed up when the conversation shifted from schedule to mental load."),
            KeyMoment(timeMark: "0:42", summary: "Separating logistics from fairness gave the conversation structure again.")
        ],
        defaultSuggestion: "When a practical conversation suddenly feels charged, check whether the real issue is emotional before solving the plan."
    )

    private static let vulnerableScenario = ScenarioTemplate(
        id: "vulnerable-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .vulnerableConversation,
            goal: .beHonest
        ),
        durationMinutes: 12,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .you, text: "There’s something I’ve been sitting on for a while because I didn’t want it to sound bigger than it is."),
            TranscriptBeat(offsetSeconds: 9, speaker: .partner, text: "You can just say it. I’d rather hear the real thing."),
            TranscriptBeat(offsetSeconds: 18, speaker: .you, text: "I’ve been feeling a little lonely with us lately, even though I know we’re both trying."),
            TranscriptBeat(offsetSeconds: 27, speaker: .partner, text: "I’m glad you said that. I’ve felt some distance too, but I didn’t know if I was imagining it."),
            TranscriptBeat(offsetSeconds: 36, speaker: .you, text: "I think I kept bringing it up sideways instead of just saying I miss you."),
            TranscriptBeat(offsetSeconds: 44, speaker: .partner, text: "That lands a lot more clearly.")
        ],
        headline: "The conversation got stronger once you said the vulnerable part plainly.",
        patternTitle: "Careful honesty",
        whatWentWell: "You named something tender without making it accusatory, and that created room for the other person to meet you.",
        whereItGotHarder: "At the beginning, you circled the issue carefully enough that it took a moment for the real point to arrive.",
        howYouShowedUp: "You were thoughtful and emotionally aware, but you approached the hardest sentence with caution.",
        keyMoments: [
            KeyMoment(timeMark: "0:18", summary: "The conversation opened up as soon as you named loneliness directly."),
            KeyMoment(timeMark: "0:36", summary: "You connected the pattern of saying it sideways to the feeling underneath.")
        ],
        defaultSuggestion: "Say the vulnerable thing a little sooner so the conversation can organize around what is actually true."
    )

    private static let decisionScenario = ScenarioTemplate(
        id: "decision-partner",
        setup: ConversationSetup(
            relationshipType: .partner,
            conversationType: .decision,
            goal: .beClear
        ),
        durationMinutes: 13,
        sourceLabel: "Prototype sample conversation",
        transcript: [
            TranscriptBeat(offsetSeconds: 0, speaker: .partner, text: "I need to know whether we’re actually saying yes to the trip or just talking around it again."),
            TranscriptBeat(offsetSeconds: 10, speaker: .you, text: "I think I’ve been talking around it because part of me wants to go and part of me is already stressed by it."),
            TranscriptBeat(offsetSeconds: 20, speaker: .partner, text: "That’s helpful. I just need the actual hesitation, not the vague version."),
            TranscriptBeat(offsetSeconds: 30, speaker: .you, text: "My hesitation is money and recovery time. If we go, I want to go without pretending those aren’t real."),
            TranscriptBeat(offsetSeconds: 40, speaker: .partner, text: "Okay, that’s finally specific. Now we can decide.")
        ],
        headline: "This conversation moved once your hesitation became specific enough to work with.",
        patternTitle: "Clarity unlock",
        whatWentWell: "You eventually made the real constraint visible, which changed the conversation from circling into decision-making.",
        whereItGotHarder: "The first stretch felt stalled because the conversation stayed in abstraction rather than naming the actual tradeoff.",
        howYouShowedUp: "You became much more effective once your concern was concrete enough for both people to respond to.",
        keyMoments: [
            KeyMoment(timeMark: "0:20", summary: "The request for the actual hesitation changed the tone from vague to workable."),
            KeyMoment(timeMark: "0:30", summary: "Naming money and recovery time turned the conversation into a real decision.")
        ],
        defaultSuggestion: "State the real tradeoff earlier so the conversation can move from ambiguity to choice."
    )
}
