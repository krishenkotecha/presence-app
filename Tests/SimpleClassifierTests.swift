import XCTest
@testable import Presence

@MainActor
final class SimpleClassifierTests: XCTestCase {
    func testConflictGoalsSurfaceCalmAndUnderstanding() {
        let store = SessionStore()

        let goals = store.goals(for: .conflict)

        XCTAssertEqual(goals, [.beUnderstood, .stayCalm, .resolveSomething, .setBoundary])
    }

    func testCoachEngineAdaptsSuggestionToGoal() {
        let scenario = ScenarioLibrary.scenario(
            for: ConversationSetup(
                relationshipType: .partner,
                conversationType: .conflict,
                goal: .stayCalm
            ),
            existingCount: 0
        )

        let active = ActiveConversation(
            id: UUID(),
            setup: ConversationSetup(
                relationshipType: .partner,
                conversationType: .conflict,
                goal: .stayCalm
            ),
            scenario: scenario,
            startedAt: .now
        )

        let session = CoachEngine.makeSession(
            from: active,
            ratings: ConversationRatings(productive: 4, alignment: 4, note: ""),
            priorSessions: []
        )

        XCTAssertTrue(session.reflection.nextTimeSuggestion.contains("slow your pace"))
    }
}
