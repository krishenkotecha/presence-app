import Foundation

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case partner
    case family
    case friend
    case coworker
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .partner: "Partner"
        case .family: "Family"
        case .friend: "Friend"
        case .coworker: "Coworker"
        case .other: "Other"
        }
    }

    var shortLabel: String {
        switch self {
        case .partner: "Partner"
        case .family: "Family"
        case .friend: "Friend"
        case .coworker: "Work"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .partner: "heart.fill"
        case .family: "house.fill"
        case .friend: "person.2.fill"
        case .coworker: "briefcase.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

enum ConversationType: String, Codable, CaseIterable, Identifiable {
    case checkIn
    case conflict
    case repair
    case planning
    case vulnerableConversation
    case decision
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .checkIn: "Check-in"
        case .conflict: "Conflict"
        case .repair: "Repair"
        case .planning: "Planning"
        case .vulnerableConversation: "Vulnerable conversation"
        case .decision: "Decision"
        case .other: "Other"
        }
    }

    var shortLabel: String {
        switch self {
        case .vulnerableConversation: "Vulnerable"
        case .other: "Other"
        default: label
        }
    }

    var symbolName: String {
        switch self {
        case .checkIn: "bubble.left.and.bubble.right.fill"
        case .conflict: "flame.fill"
        case .repair: "bandage.fill"
        case .planning: "calendar"
        case .vulnerableConversation: "hand.raised.fill"
        case .decision: "point.topleft.down.curvedto.point.bottomright.up.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

enum ConversationGoal: String, Codable, CaseIterable, Identifiable {
    case beUnderstood
    case stayCalm
    case beHonest
    case resolveSomething
    case feelCloser
    case setBoundary
    case beClear
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beUnderstood: "Be understood"
        case .stayCalm: "Stay calm"
        case .beHonest: "Be honest"
        case .resolveSomething: "Resolve something"
        case .feelCloser: "Feel closer"
        case .setBoundary: "Set a boundary"
        case .beClear: "Be clear"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .beUnderstood: "ear.fill"
        case .stayCalm: "leaf.fill"
        case .beHonest: "sparkles"
        case .resolveSomething: "checkmark.circle.fill"
        case .feelCloser: "heart.fill"
        case .setBoundary: "hand.raised.fill"
        case .beClear: "text.alignleft"
        case .other: "ellipsis.circle.fill"
        }
    }
}

struct ConversationSetup: Codable, Equatable, Hashable {
    var relationshipType: RelationshipType?
    var conversationType: ConversationType?
    var goal: ConversationGoal?
    var customRelationshipDescription: String?
    var customConversationTypeDescription: String?
    var customGoalDescription: String?
    var wasSkipped: Bool = false

    init(
        relationshipType: RelationshipType? = nil,
        conversationType: ConversationType? = nil,
        goal: ConversationGoal? = nil,
        customRelationshipDescription: String? = nil,
        customConversationTypeDescription: String? = nil,
        customGoalDescription: String? = nil,
        wasSkipped: Bool = false
    ) {
        self.relationshipType = relationshipType
        self.conversationType = conversationType
        self.goal = goal
        self.customRelationshipDescription = customRelationshipDescription
        self.customConversationTypeDescription = customConversationTypeDescription
        self.customGoalDescription = customGoalDescription
        self.wasSkipped = wasSkipped
    }

    var canStart: Bool {
        relationshipType != nil && conversationType != nil
    }

    var relationshipDisplayLabel: String? {
        if relationshipType == .other {
            return customRelationshipDescription?.trimmedNonEmpty ?? relationshipType?.label
        }
        return relationshipType?.label
    }

    var conversationTypeDisplayLabel: String? {
        if conversationType == .other {
            return customConversationTypeDescription?.trimmedNonEmpty ?? conversationType?.label
        }
        return conversationType?.label
    }

    var goalDisplayLabel: String? {
        if goal == .other {
            return customGoalDescription?.trimmedNonEmpty ?? goal?.label
        }
        return goal?.label
    }
}

enum TranscriptSpeaker: String, Codable {
    case you
    case partner

    var label: String {
        switch self {
        case .you: "You"
        case .partner: "Them"
        }
    }
}

struct TranscriptBeat: Identifiable, Codable, Hashable {
    let id: UUID
    let offsetSeconds: TimeInterval
    let speaker: TranscriptSpeaker
    let text: String

    init(
        id: UUID = UUID(),
        offsetSeconds: TimeInterval,
        speaker: TranscriptSpeaker,
        text: String
    ) {
        self.id = id
        self.offsetSeconds = offsetSeconds
        self.speaker = speaker
        self.text = text
    }
}

struct KeyMoment: Identifiable, Codable, Hashable {
    let id: UUID
    let timeMark: String
    let summary: String

    init(id: UUID = UUID(), timeMark: String, summary: String) {
        self.id = id
        self.timeMark = timeMark
        self.summary = summary
    }
}

struct ConversationReflection: Codable, Hashable {
    let headline: String
    let patternTitle: String
    let whatWentWell: String
    let whereItGotHarder: String
    let howYouShowedUp: String
    let nextTimeSuggestion: String
    let keyMoments: [KeyMoment]
}

struct ConversationRatings: Codable, Hashable {
    let productive: Int
    let alignment: Int
    let note: String
}

struct ConversationSession: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let durationMinutes: Int
    let setup: ConversationSetup
    let transcript: [TranscriptBeat]
    let reflection: ConversationReflection
    let ratings: ConversationRatings
    let sourceLabel: String

    var title: String {
        let relationship = setup.relationshipDisplayLabel ?? "Conversation"
        let type = setup.conversationTypeDisplayLabel ?? "Session"
        return "\(relationship) \(type)"
    }

    var goalLabel: String? {
        setup.goalDisplayLabel
    }
}

struct ScenarioTemplate: Hashable {
    let id: String
    let setup: ConversationSetup
    let durationMinutes: Int
    let sourceLabel: String
    let transcript: [TranscriptBeat]
    let headline: String
    let patternTitle: String
    let whatWentWell: String
    let whereItGotHarder: String
    let howYouShowedUp: String
    let keyMoments: [KeyMoment]
    let defaultSuggestion: String
}

struct ActiveConversation: Identifiable, Hashable {
    let id: UUID
    let setup: ConversationSetup
    let scenario: ScenarioTemplate
    let startedAt: Date

    var durationMinutes: Int {
        scenario.durationMinutes
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
