import Foundation

struct PersonalInsight: Identifiable, Hashable {
    let id = UUID()
    let trigger: String
    let stat: String?
    let detail: String
}

struct PredictiveAlert: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

enum KeyRelationshipKind: String, CaseIterable, Identifiable, Hashable {
    case partner
    case boss
    case family
    case friend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partner: "Partner"
        case .boss: "Boss"
        case .family: "Family"
        case .friend: "Friend"
        }
    }
}

struct KeyRelationshipProfile: Identifiable, Hashable {
    let kind: KeyRelationshipKind
    let headline: String
    let summary: String
    let signals: [String]

    var id: KeyRelationshipKind { kind }
}

struct BlindSpotInsight: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

struct ConversationTypeProfile: Identifiable, Hashable {
    let type: ConversationType
    let headline: String
    let summary: String
    let guidance: String

    var id: ConversationType { type }
}

struct ProgressHighlight: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

struct DiscoveryCard: Hashable {
    let title: String
    let evidence: String
    let detail: String
}

struct PersonSnapshot: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let status: String
    let direction: String
}

struct RecentDiscovery: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let context: String
}

enum PatternPersonFilter: String, CaseIterable, Identifiable, Hashable {
    case all, partner, team, sarah, mom
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum PatternConversationFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case oneOnOne
    case meeting
    case date
    case coaching
    case family

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "All"
        case .oneOnOne: "1:1"
        case .meeting: "Meeting"
        case .date: "Date"
        case .coaching: "Coaching"
        case .family: "Family"
        }
    }
}

enum PatternTopicFilter: String, CaseIterable, Identifiable, Hashable {
    case all, money, work, plans, conflict, support
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum PatternTimeFilter: String, CaseIterable, Identifiable, Hashable {
    case days7, days30, days90, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .days7: "7D"
        case .days30: "30D"
        case .days90: "90D"
        case .all: "All"
        }
    }
}

enum PatternMetricFilter: String, CaseIterable, Identifiable, Hashable {
    case listening, curiosity, interruptions, validation, directness, warmth
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct PatternDashboardFilters: Hashable {
    var person: PatternPersonFilter = .all
    var conversationType: PatternConversationFilter = .all
    var topic: PatternTopicFilter = .all
    var time: PatternTimeFilter = .days30
    var metric: PatternMetricFilter = .listening
}

struct PatternMetricSummary: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let delta: String
}

struct PatternChartPoint: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
}

struct PatternHistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let dateLabel: String
    let person: PatternPersonFilter
    let personLabel: String
    let conversationType: PatternConversationFilter
    let topics: [PatternTopicFilter]
    let durationMinutes: Int
    let signal: String
    let summary: String

    var meta: String {
        "\(dateLabel) • \(personLabel) • \(conversationType.label) • \(durationMinutes) min"
    }

    var tags: [String] {
        topics.map(\.label)
    }
}

struct PatternDashboardData: Hashable {
    let keyFindingTitle: String
    let keyFindingDetail: String
    let keyFindingEvidence: String
    let summaries: [PatternMetricSummary]
    let chartTitle: String
    let chartSubtitle: String
    let chartPoints: [PatternChartPoint]
    let explanationTitle: String
    let explanationBullets: [String]
    let insights: [String]
    let history: [PatternHistoryEntry]
    let emptyState: String?
}

struct PatternHeatmapRow: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let values: [Double]
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [ConversationSession]

    init() {
        sessions = ScenarioLibrary.seededSessions()
    }

    var recentSessions: [ConversationSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var latestSession: ConversationSession? {
        recentSessions.first
    }

    var latestSetup: ConversationSetup {
        recentSessions.first?.setup ?? ConversationSetup(
            relationshipType: .partner,
            conversationType: .repair,
            goal: .feelCloser
        )
    }

    var latestNextStepSummary: String {
        guard let latestSession else {
            return "Start your first coached conversation and Presence will keep one next-step reminder here."
        }

        return latestSession.reflection.nextTimeSuggestion
    }

    var latestNextStepContext: String {
        guard let latestSession else {
            return "Your most recent reflection will show up here."
        }

        return "\(latestSession.setup.relationshipDisplayLabel ?? "Conversation") • \(latestSession.setup.conversationTypeDisplayLabel ?? "Reflection")"
    }

    var recurringPatternSummary: String {
        let titles = recentSessions.map(\.reflection.patternTitle)
        guard let mostCommon = titles.mostCommon else {
            return "Start your first coached conversation to surface patterns over time."
        }

        switch mostCommon {
        case "Explanation mode":
            return "You tend to explain quickly once emotion enters the room."
        case "Logistics first":
            return "You often move to logistics before the emotional layer is settled."
        case "Careful honesty":
            return "You usually stay thoughtful, but sometimes soften the point that matters most."
        default:
            return "A few communication patterns are starting to repeat across important conversations."
        }
    }

    var improvementSummary: String {
        let productiveAverage = average(of: recentSessions.map(\.ratings.productive))
        if productiveAverage >= 4.3 {
            return "Recent sessions feel more productive overall, especially once you stay with the core issue."
        }

        return "Your best conversations stay grounded when you slow down and name the real issue earlier."
    }

    var personalInsights: [PersonalInsight] {
        [
            PersonalInsight(
                trigger: "when you’re discussing topics you consider yourself an expert in",
                stat: "+40%",
                detail: "You speak 40% more when discussing topics you consider yourself an expert in."
            ),
            PersonalInsight(
                trigger: "with men",
                stat: "2x",
                detail: "You interrupt men twice as often as women."
            ),
            PersonalInsight(
                trigger: "after 4 PM",
                stat: nil,
                detail: "You become significantly less patient after 4 PM."
            ),
            PersonalInsight(
                trigger: "with people older than you",
                stat: nil,
                detail: "You ask fewer questions when talking to people older than you."
            ),
            PersonalInsight(
                trigger: "on days with poor sleep",
                stat: nil,
                detail: "Your communication quality drops on days with poor sleep."
            ),
            PersonalInsight(
                trigger: "when the subject is money",
                stat: nil,
                detail: "You become more direct when discussing money."
            ),
            PersonalInsight(
                trigger: "when the subject is relationships",
                stat: nil,
                detail: "You become more tentative when discussing relationships."
            ),
            PersonalInsight(
                trigger: "when you feel challenged",
                stat: nil,
                detail: "You talk fastest when you feel challenged."
            )
        ]
    }

    var predictiveAlerts: [PredictiveAlert] {
        [
            PredictiveAlert(
                title: "Money conversations are getting sharper",
                detail: "Discussions about money have become more adversarial over the last 60 days."
            ),
            PredictiveAlert(
                title: "You’re becoming more directive",
                detail: "Recent conversations show more instruction and less curiosity than your baseline."
            ),
            PredictiveAlert(
                title: "Your team is participating less",
                detail: "In meetings you lead, other voices are contributing less often than they did last month."
            )
        ]
    }

    var keyRelationshipProfiles: [KeyRelationshipProfile] {
        [
            KeyRelationshipProfile(
                kind: .partner,
                headline: "You get more direct when the stakes feel emotional.",
                summary: "With your partner, you usually stay engaged, but you shift into explanation quickly when you feel misunderstood.",
                signals: [
                    "You ask more follow-up questions during repair than during conflict.",
                    "Money conversations bring out a sharper tone faster than other topics.",
                    "Your partner tends to feel more heard when you reflect back before solving."
                ]
            ),
            KeyRelationshipProfile(
                kind: .boss,
                headline: "You become more concise and more deferential.",
                summary: "With your boss, you tighten up, hedge stronger opinions, and ask fewer clarifying questions than you do with peers.",
                signals: [
                    "You use apologetic language more often before making a recommendation.",
                    "You interrupt less, but you also leave uncertainty hanging longer.",
                    "You sound clearest when you name the tradeoff directly."
                ]
            ),
            KeyRelationshipProfile(
                kind: .family,
                headline: "Old roles show up fast.",
                summary: "With family, you become more patient on the surface but more likely to circle around what you actually mean.",
                signals: [
                    "You soften disagreement with humor more often here than anywhere else.",
                    "You ask fewer direct questions once tension starts rising.",
                    "Conversations go better when you state the issue earlier."
                ]
            ),
            KeyRelationshipProfile(
                kind: .friend,
                headline: "You’re warmer, but less direct.",
                summary: "With friends, you create ease quickly, though you sometimes avoid naming disappointment or need clearly.",
                signals: [
                    "You validate often before saying something hard.",
                    "You hedge good ideas more with friends than with coworkers.",
                    "You sound most like yourself here."
                ]
            )
        ]
    }

    var blindSpotInsights: [BlindSpotInsight] {
        [
            BlindSpotInsight(
                title: "You say “actually” 87 times a week.",
                detail: "It often shows up when you’re correcting or tightening someone else’s framing."
            ),
            BlindSpotInsight(
                title: "You often begin disagreement with “yeah, but.”",
                detail: "It softens the opening, but still signals that you’re about to override what was just said."
            ),
            BlindSpotInsight(
                title: "You almost never ask someone how they feel.",
                detail: "You tend to ask what happened or what to do next instead."
            ),
            BlindSpotInsight(
                title: "You frequently hedge good ideas with apologetic language.",
                detail: "Phrases like “sorry” or “this might be dumb” often come before your strongest points."
            ),
            BlindSpotInsight(
                title: "You answer your own questions before others can respond.",
                detail: "You often fill the silence before the other person has a chance to think out loud."
            )
        ]
    }

    var conversationTypeProfiles: [ConversationTypeProfile] {
        [
            ConversationTypeProfile(
                type: .conflict,
                headline: "Conflict brings out speed and certainty.",
                summary: "You speak faster, interrupt more, and move into explanation quickly when you feel challenged.",
                guidance: "These conversations go better when you reflect back once before making your point."
            ),
            ConversationTypeProfile(
                type: .repair,
                headline: "Repair is where your curiosity comes back.",
                summary: "You ask better follow-up questions here than in conflict, especially once the other person feels acknowledged.",
                guidance: "Naming the hurt directly seems to make you more effective than staying in logistics."
            ),
            ConversationTypeProfile(
                type: .planning,
                headline: "Planning conversations can hide emotional friction.",
                summary: "You often stay calm on the surface, but the tone shifts when appreciation or fairness is underneath the logistics.",
                guidance: "Your clearest planning conversations name the emotional subtext earlier."
            ),
            ConversationTypeProfile(
                type: .vulnerableConversation,
                headline: "Vulnerability makes you softer, but more tentative.",
                summary: "You stay engaged, though you often soften the exact point that matters most.",
                guidance: "You tend to feel better about these conversations when you are direct a little earlier."
            ),
            ConversationTypeProfile(
                type: .decision,
                headline: "Decisions make you more structured.",
                summary: "You get clearer and more concise here, but sometimes skip over how the other person is reacting.",
                guidance: "A quick check for alignment before closing the decision usually helps."
            ),
            ConversationTypeProfile(
                type: .checkIn,
                headline: "Check-ins are where your warmth shows up most naturally.",
                summary: "You validate easily and create ease quickly, though you can avoid the harder truth if it appears.",
                guidance: "These go best when you stay in the easy tone but still name what matters."
            )
        ]
    }

    var progressHighlights: [ProgressHighlight] {
        [
            ProgressHighlight(
                title: "You interrupt less than you did last month.",
                detail: "Across recent conversations, you’re leaving more space before jumping in."
            ),
            ProgressHighlight(
                title: "You’re asking more follow-up questions in repair conversations.",
                detail: "That shift seems to correlate with stronger productive ratings afterward."
            ),
            ProgressHighlight(
                title: "Finance conversations feel less brittle than they used to.",
                detail: "Your partner reports feeling more heard when you slow down before explaining."
            )
        ]
    }

    var greetingName: String {
        "Krishen"
    }

    var homeStatusLine: String {
        "1 new insight • 2 patterns to watch"
    }

    var todaysDiscovery: DiscoveryCard {
        DiscoveryCard(
            title: "You become more persuasive when you tell a story before making a recommendation.",
            evidence: "Seen in 12 conversations",
            detail: "Your strongest recommendation moments usually start with one concrete example before you shift into analysis."
        )
    }

    var homePatternAlerts: [PredictiveAlert] {
        Array(predictiveAlerts.prefix(2))
    }

    var peopleSnapshots: [PersonSnapshot] {
        [
            PersonSnapshot(name: "Partner", status: "Warmer", direction: "↑"),
            PersonSnapshot(name: "Team", status: "Participation", direction: "↓"),
            PersonSnapshot(name: "Sarah", status: "Trust", direction: "↑"),
            PersonSnapshot(name: "Mom", status: "Tension", direction: "↓")
        ]
    }

    var askSuggestions: [String] {
        [
            "Why do conversations with my partner get tense?",
            "Am I becoming a better listener?",
            "Who do I interrupt most?",
            "What changed this month?"
        ]
    }

    var recentDiscoveries: [RecentDiscovery] {
        [
            RecentDiscovery(
                title: "You speak faster after 4 PM.",
                context: "Especially true in work conversations when you already know your position."
            ),
            RecentDiscovery(
                title: "You ask more follow-up questions in 1:1s than group meetings.",
                context: "Most noticeable with your partner and in coaching-style conversations."
            ),
            RecentDiscovery(
                title: "You are more patient with direct reports than peers.",
                context: "The difference is strongest when the conversation is about support rather than decisions."
            )
        ]
    }

    func patternsDashboard(for filters: PatternDashboardFilters) -> PatternDashboardData {
        let filteredHistory = filteredPatternHistory(for: filters)

        if filteredHistory.isEmpty {
            return PatternDashboardData(
                keyFindingTitle: "Key finding",
                keyFindingDetail: "You become more solution-oriented during money conversations.",
                keyFindingEvidence: "Validation drops 22% and interruptions rise 18% compared with your baseline.",
                summaries: [
                    PatternMetricSummary(title: "Talk time", value: "--", delta: "No data"),
                    PatternMetricSummary(title: "Interruptions", value: "--", delta: "No data"),
                    PatternMetricSummary(title: "Questions", value: "--", delta: "No data"),
                    PatternMetricSummary(title: filters.metric.label, value: "--", delta: "No data")
                ],
                chartTitle: chartTitle(for: filters.metric),
                chartSubtitle: "\(filters.person.label) • \(filters.conversationType.label) • \(filters.time.label)",
                chartPoints: [],
                explanationTitle: "Why this isn’t available yet",
                explanationBullets: [
                    "No matching conversations have been recorded for this slice.",
                    "Try widening time, person, or topic filters.",
                    "Presence will explain the shift once enough evidence exists."
                ],
                insights: [],
                history: [],
                emptyState: "No conversations match these filters yet."
            )
        }

        if filters.person == .partner && filters.topic == .money && filters.time == .days90 {
            return PatternDashboardData(
                keyFindingTitle: "Key finding",
                keyFindingDetail: "You become more solution-oriented during money conversations.",
                keyFindingEvidence: "Validation drops 22% and interruptions rise 18% compared with your baseline.",
                summaries: [
                    PatternMetricSummary(title: "Talk time", value: "58%", delta: "↑ 6%"),
                    PatternMetricSummary(title: "Interruptions", value: "18", delta: "↑ 12%"),
                    PatternMetricSummary(title: "Questions", value: "14", delta: "↓ 9%"),
                    PatternMetricSummary(title: "Warmth", value: "71", delta: "↓ 4%")
                ],
                chartTitle: "Interruptions over 90 days",
                chartSubtitle: "Partner • Money",
                chartPoints: [
                    PatternChartPoint(label: "W1", value: 0.34),
                    PatternChartPoint(label: "W2", value: 0.39),
                    PatternChartPoint(label: "W3", value: 0.44),
                    PatternChartPoint(label: "W4", value: 0.51),
                    PatternChartPoint(label: "W5", value: 0.47),
                    PatternChartPoint(label: "W6", value: 0.58)
                ],
                explanationTitle: "Why money conversations sharpen",
                explanationBullets: [
                    "Interruptions rise once fairness replaces logistics as the frame.",
                    "Follow-up questions decline when you feel responsible for solving it.",
                    "Validation drops before directness spikes."
                ],
                insights: [
                    "With Partner + Money selected, interruptions are 2.4x higher than in other partner topics.",
                    "Warmth tends to dip once the conversation shifts from planning to fairness.",
                    "These conversations go better when you reflect back before explaining intent."
                ],
                history: [
                    PatternHistoryEntry(title: "Dinner Conversation", dateLabel: "May 26", person: .partner, personLabel: "Partner", conversationType: .date, topics: [.money, .conflict], durationMinutes: 58, signal: "Warmer than baseline • Money discussed", summary: "Tension rose when appreciation became part of the topic."),
                    PatternHistoryEntry(title: "Sunday Planning", dateLabel: "May 18", person: .partner, personLabel: "Partner", conversationType: .date, topics: [.money, .plans], durationMinutes: 42, signal: "Interruptions up • 3 key moments", summary: "The conversation became sharper once spending tradeoffs felt personal.")
                ],
                emptyState: nil
            )
        }

        switch filters.metric {
        case .interruptions:
            return PatternDashboardData(
                keyFindingTitle: "Key finding",
                keyFindingDetail: "Your interruptions are concentrated in higher-stakes group settings.",
                keyFindingEvidence: "They’re down overall, but still cluster when you already have a strong point of view.",
                summaries: [
                    PatternMetricSummary(title: "Talk time", value: "54%", delta: "↓ 3%"),
                    PatternMetricSummary(title: "Interruptions", value: "↓ 18%", delta: "vs last month"),
                    PatternMetricSummary(title: "Questions", value: "27", delta: "↑ 12%"),
                    PatternMetricSummary(title: "Warmth", value: "78", delta: "↑ 9%")
                ],
                chartTitle: "Interruptions by conversation type",
                chartSubtitle: "\(filters.person.label) • \(filters.time.label)",
                chartPoints: [
                    PatternChartPoint(label: "1:1", value: 0.22),
                    PatternChartPoint(label: "Meeting", value: 0.48),
                    PatternChartPoint(label: "Date", value: 0.31),
                    PatternChartPoint(label: "Coaching", value: 0.14),
                    PatternChartPoint(label: "Family", value: 0.36)
                ],
                explanationTitle: "Why interruptions improved",
                explanationBullets: [
                    "You leave more space in 1:1 conversations than in group settings.",
                    "Meeting interruptions have declined over the last 30 days.",
                    "You pause longer before responding when the goal is repair."
                ],
                insights: [
                    "You interrupt most in group settings where you already have a strong point of view.",
                    "1:1 conversations create much more space before you respond.",
                    "Meeting interruptions have declined over the last 30 days."
                ],
                history: filteredHistory,
                emptyState: nil
            )
        case .warmth:
            return PatternDashboardData(
                keyFindingTitle: "Key finding",
                keyFindingDetail: "Warmth changes more by person than by topic.",
                keyFindingEvidence: "You sound noticeably warmer with your partner and Sarah than with family or team conversations.",
                summaries: [
                    PatternMetricSummary(title: "Talk time", value: "51%", delta: "steady"),
                    PatternMetricSummary(title: "Interruptions", value: "12", delta: "↓ 5%"),
                    PatternMetricSummary(title: "Questions", value: "31", delta: "↑ 8%"),
                    PatternMetricSummary(title: "Warmth", value: "↑ 9%", delta: "this month")
                ],
                chartTitle: "Warmth by person",
                chartSubtitle: "\(filters.topic.label) • \(filters.time.label)",
                chartPoints: [
                    PatternChartPoint(label: "Partner", value: 0.72),
                    PatternChartPoint(label: "Team", value: 0.51),
                    PatternChartPoint(label: "Sarah", value: 0.68),
                    PatternChartPoint(label: "Mom", value: 0.43)
                ],
                explanationTitle: "Why warmth improved",
                explanationBullets: [
                    "Validation and warmth tend to rise together in support conversations.",
                    "You sound warmest when curiosity leads before advice.",
                    "Family conflict is still the fastest way warmth drops."
                ],
                insights: [
                    "You sound warmest with your partner and in coaching-style conversations.",
                    "Warmth drops fastest when conflict topics appear in family conversations.",
                    "Support-oriented conversations raise your validation and warmth together."
                ],
                history: filteredHistory,
                emptyState: nil
            )
        default:
            return PatternDashboardData(
                keyFindingTitle: "Key finding",
                keyFindingDetail: keyFindingDetail(for: filters),
                keyFindingEvidence: keyFindingEvidence(for: filters),
                summaries: metricSummaries(for: filters),
                chartTitle: chartTitle(for: filters.metric),
                chartSubtitle: "\(filters.person.label) • \(filters.conversationType.label) • \(filters.time.label)",
                chartPoints: chartPoints(for: filters),
                explanationTitle: explanationTitle(for: filters),
                explanationBullets: explanationBullets(for: filters),
                insights: defaultInsights(for: filters),
                history: filteredHistory,
                emptyState: nil
            )
        }
    }

    func goals(for type: ConversationType?) -> [ConversationGoal] {
        guard let type else {
            return [.beUnderstood, .stayCalm, .beHonest, .resolveSomething, .feelCloser, .setBoundary]
        }

        switch type {
        case .checkIn:
            return [.feelCloser, .beHonest, .beUnderstood, .stayCalm]
        case .conflict:
            return [.beUnderstood, .stayCalm, .resolveSomething, .setBoundary]
        case .repair:
            return [.feelCloser, .beHonest, .beUnderstood, .resolveSomething]
        case .planning:
            return [.beClear, .resolveSomething, .stayCalm, .beUnderstood]
        case .vulnerableConversation:
            return [.beHonest, .feelCloser, .beUnderstood, .stayCalm]
        case .decision:
            return [.beClear, .beUnderstood, .resolveSomething, .stayCalm]
        case .other:
            return [.beUnderstood, .beHonest, .stayCalm, .resolveSomething]
        }
    }

    func startSession(with setup: ConversationSetup) -> ActiveConversation {
        let scenario = ScenarioLibrary.scenario(for: setup, existingCount: sessions.count)
        return ActiveConversation(
            id: UUID(),
            setup: setup,
            scenario: scenario,
            startedAt: Date()
        )
    }

    @discardableResult
    func completeSession(
        activeSession: ActiveConversation,
        ratings: ConversationRatings
    ) -> ConversationSession {
        let session = CoachEngine.makeSession(
            from: activeSession,
            ratings: ratings,
            priorSessions: recentSessions
        )
        sessions.insert(session, at: 0)
        return session
    }

    private func average(of values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return Double(total) / Double(values.count)
    }

    private func metricHeadlineValue(for metric: PatternMetricFilter) -> String {
        switch metric {
        case .listening: "82"
        case .curiosity: "27"
        case .interruptions: "↓ 18%"
        case .validation: "74"
        case .directness: "68"
        case .warmth: "79"
        }
    }

    private func metricDelta(for metric: PatternMetricFilter) -> String {
        switch metric {
        case .listening: "↑ 6%"
        case .curiosity: "↑ 12%"
        case .interruptions: "vs last month"
        case .validation: "↑ 5%"
        case .directness: "↑ 3%"
        case .warmth: "↑ 9%"
        }
    }

    private func chartTitle(for metric: PatternMetricFilter) -> String {
        switch metric {
        case .listening: "Listening over time"
        case .curiosity: "Curiosity over time"
        case .interruptions: "Interruptions over time"
        case .validation: "Validation over time"
        case .directness: "Directness over time"
        case .warmth: "Warmth over time"
        }
    }

    private func defaultChartPoints(for metric: PatternMetricFilter) -> [PatternChartPoint] {
        switch metric {
        case .listening:
            return [0.54, 0.59, 0.61, 0.66, 0.71, 0.74].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        case .curiosity:
            return [0.28, 0.31, 0.33, 0.36, 0.41, 0.44].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        case .interruptions:
            return [0.56, 0.51, 0.48, 0.44, 0.39, 0.34].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        case .validation:
            return [0.41, 0.45, 0.49, 0.52, 0.56, 0.6].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        case .directness:
            return [0.48, 0.51, 0.53, 0.58, 0.61, 0.63].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        case .warmth:
            return [0.52, 0.57, 0.6, 0.64, 0.68, 0.73].enumerated().map { PatternChartPoint(label: "W\($0.offset + 1)", value: $0.element) }
        }
    }

    private func chartPoints(for filters: PatternDashboardFilters) -> [PatternChartPoint] {
        let base = defaultChartPoints(for: filters.metric)
        let multiplier: Double

        switch filters.person {
        case .partner: multiplier = 1.04
        case .team: multiplier = 0.94
        case .sarah: multiplier = 1.08
        case .mom: multiplier = 0.89
        case .all: multiplier = 1.0
        }

        return base.map { point in
            let adjusted = min(max(point.value * multiplier, 0.08), 0.92)
            return PatternChartPoint(label: point.label, value: adjusted)
        }
    }

    private func metricSummaries(for filters: PatternDashboardFilters) -> [PatternMetricSummary] {
        let baseTalkTime: String
        let baseInterruptions: String
        let baseQuestions: String
        let warmthDelta: String

        switch filters.person {
        case .partner:
            baseTalkTime = "56%"
            baseInterruptions = "↓ 8%"
            baseQuestions = "↑ 14%"
            warmthDelta = "↑ 6%"
        case .team:
            baseTalkTime = "62%"
            baseInterruptions = "↓ 3%"
            baseQuestions = "↑ 4%"
            warmthDelta = "↓ 2%"
        case .sarah:
            baseTalkTime = "48%"
            baseInterruptions = "↓ 21%"
            baseQuestions = "↑ 18%"
            warmthDelta = "↑ 11%"
        case .mom:
            baseTalkTime = "53%"
            baseInterruptions = "↑ 7%"
            baseQuestions = "↓ 5%"
            warmthDelta = "↓ 4%"
        case .all:
            baseTalkTime = "58%"
            baseInterruptions = "↓ 18%"
            baseQuestions = "↑ 12%"
            warmthDelta = "↑ 9%"
        }

        return [
            PatternMetricSummary(title: "Talk time", value: baseTalkTime, delta: "vs baseline"),
            PatternMetricSummary(title: "Interruptions", value: baseInterruptions, delta: metricContext(for: filters.time)),
            PatternMetricSummary(title: "Questions", value: baseQuestions, delta: metricContext(for: filters.time)),
            PatternMetricSummary(
                title: filters.metric.label,
                value: metricHeadlineValue(for: filters.metric),
                delta: filters.metric == .warmth ? warmthDelta : metricDelta(for: filters.metric)
            )
        ]
    }

    private func metricContext(for time: PatternTimeFilter) -> String {
        switch time {
        case .days7: "past week"
        case .days30: "past month"
        case .days90: "90 days"
        case .all: "all time"
        }
    }

    private func defaultInsights(for filters: PatternDashboardFilters) -> [String] {
        let personFragment = filters.person == .all ? "Across all people" : "With \(filters.person.label)"
        let topicFragment = filters.topic == .all ? "across topics" : "when the topic is \(filters.topic.label.lowercased())"
        let typeFragment = filters.conversationType == .all ? "across conversation types" : "in \(filters.conversationType.label.lowercased()) conversations"

        return [
            "\(personFragment), you show more interruption risk \(topicFragment) than in your broader baseline.",
            "Your \(filters.metric.label.lowercased()) shifts most \(typeFragment), especially over the last \(filters.time.label.lowercased()).",
            "You ask more follow-up questions in 1:1s than group conversations, and that pattern still holds under this filter."
        ]
    }

    func heatmapRows(for filters: PatternDashboardFilters) -> [PatternHeatmapRow] {
        let rows: [(String, [Double])] = [
            ("Partner", [0.72, 0.68, 0.41, 0.64]),
            ("Team", [0.51, 0.48, 0.63, 0.71]),
            ("Sarah", [0.77, 0.74, 0.22, 0.58]),
            ("Mom", [0.44, 0.39, 0.57, 0.67])
        ]

        let adjusted: Double
        switch filters.metric {
        case .listening: adjusted = 0.02
        case .curiosity: adjusted = 0.05
        case .interruptions: adjusted = -0.04
        case .validation: adjusted = 0.03
        case .directness: adjusted = 0.06
        case .warmth: adjusted = 0.04
        }

        return rows.map { row in
            PatternHeatmapRow(label: row.0, values: row.1.map { min(max($0 + adjusted, 0.14), 0.9) })
        }
    }

    private var defaultPatternHistory: [PatternHistoryEntry] {
        [
            PatternHistoryEntry(title: "Team Planning Meeting", dateLabel: "May 28", person: .team, personLabel: "Team", conversationType: .meeting, topics: [.work, .plans], durationMinutes: 42, signal: "Participation down • 3 key moments", summary: "You spoke more than usual once the decision narrowed."),
            PatternHistoryEntry(title: "Dinner Conversation", dateLabel: "May 26", person: .partner, personLabel: "Partner", conversationType: .date, topics: [.money, .support], durationMinutes: 58, signal: "Warmer than baseline • Money discussed", summary: "The conversation stayed calmer once you reflected back before solving."),
            PatternHistoryEntry(title: "Coaching 1:1", dateLabel: "May 22", person: .sarah, personLabel: "Sarah", conversationType: .coaching, topics: [.work, .support], durationMinutes: 31, signal: "Questions up • 2 key moments", summary: "You were more curious and less directive than usual."),
            PatternHistoryEntry(title: "Family Check-in", dateLabel: "May 19", person: .mom, personLabel: "Mom", conversationType: .family, topics: [.conflict, .support], durationMinutes: 36, signal: "Directness up • 1 key moment", summary: "You named the real issue earlier, which reduced circling."),
            PatternHistoryEntry(title: "Budget Reset", dateLabel: "May 14", person: .partner, personLabel: "Partner", conversationType: .oneOnOne, topics: [.money, .plans], durationMinutes: 47, signal: "Interruptions up • Repair attempt landed", summary: "You became more direct once the conversation turned to fairness."),
            PatternHistoryEntry(title: "Weekly Staff 1:1", dateLabel: "May 09", person: .team, personLabel: "Team", conversationType: .oneOnOne, topics: [.work, .support], durationMinutes: 28, signal: "Listening up • Warmer close", summary: "You asked more clarifying questions before shifting into recommendations.")
        ]
    }

    private func keyFindingDetail(for filters: PatternDashboardFilters) -> String {
        if filters.person == .partner && filters.topic == .money {
            return "You become more solution-oriented during money conversations."
        }

        switch filters.metric {
        case .listening:
            return "You listen best when the conversation stays one layer deeper than logistics."
        case .curiosity:
            return "Your curiosity is strongest in 1:1 conversations and coaching moments."
        case .interruptions:
            return "Interruptions cluster when you feel challenged or already know your position."
        case .validation:
            return "Validation rises when the topic is support and drops when fairness enters."
        case .directness:
            return "You become more direct in work and money conversations than in relationships."
        case .warmth:
            return "Warmth changes more by person than by topic."
        }
    }

    private func keyFindingEvidence(for filters: PatternDashboardFilters) -> String {
        switch filters.metric {
        case .listening:
            return "Listening is up 14 vs baseline, especially in 1:1s and repair conversations."
        case .curiosity:
            return "Follow-up questions are up 12% this month and highest with Sarah and Partner."
        case .interruptions:
            return "Interruptions are down 18% overall, but still spike in meetings and money topics."
        case .validation:
            return "Validation improves in support conversations and drops 22% in conflict-driven slices."
        case .directness:
            return "Directness rises 9% in work conversations and 13% in money conversations."
        case .warmth:
            return "Warmth is 11 points higher with Partner and Sarah than with Team or Mom."
        }
    }

    private func explanationTitle(for filters: PatternDashboardFilters) -> String {
        switch filters.metric {
        case .listening: return "Why listening changed"
        case .curiosity: return "Why curiosity changed"
        case .interruptions: return "Why interruptions changed"
        case .validation: return "Why validation changed"
        case .directness: return "Why directness changed"
        case .warmth: return "Why warmth changed"
        }
    }

    private func explanationBullets(for filters: PatternDashboardFilters) -> [String] {
        switch filters.metric {
        case .listening:
            return [
                "Interruptions declined 18% in your recent conversations.",
                "You paused longer before responding in repair and support moments.",
                "You reflected back more often before solving."
            ]
        case .curiosity:
            return [
                "Follow-up questions increased 12% over the last month.",
                "You stay more open in 1:1s than in group settings.",
                "Curiosity falls once you move into recommendation mode."
            ]
        case .interruptions:
            return [
                "Group settings still trigger faster overlap than 1:1s.",
                "You interrupt less when you let one beat of silence happen.",
                "Money and work topics create the sharpest spikes."
            ]
        case .validation:
            return [
                "Validation rises when support is the topic.",
                "It drops fastest when fairness becomes the subtext.",
                "Your strongest conversations include one explicit acknowledgment before advice."
            ]
        case .directness:
            return [
                "You name tradeoffs earlier in work conversations.",
                "You hedge less when the topic is concrete.",
                "Directness rises fastest when time pressure is present."
            ]
        case .warmth:
            return [
                "Warmth improves when curiosity leads before advice.",
                "It dips when logistics become identity or fairness debates.",
                "Certain people bring out more patience and softness than others."
            ]
        }
    }

    private func filteredPatternHistory(for filters: PatternDashboardFilters) -> [PatternHistoryEntry] {
        let byPerson = defaultPatternHistory.filter { entry in
            filters.person == .all || entry.person == filters.person
        }

        let byType = byPerson.filter { entry in
            filters.conversationType == .all || entry.conversationType == filters.conversationType
        }

        let byTopic = byType.filter { entry in
            filters.topic == .all || entry.topics.contains(filters.topic)
        }

        switch filters.time {
        case .days7:
            return Array(byTopic.prefix(1))
        case .days30:
            return Array(byTopic.prefix(3))
        case .days90, .all:
            return byTopic
        }
    }
}

private extension Array where Element == String {
    var mostCommon: String? {
        Dictionary(grouping: self, by: { $0 })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}
