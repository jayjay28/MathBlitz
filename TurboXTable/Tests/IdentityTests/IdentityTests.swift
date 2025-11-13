//
//  IdentityTests.swift
//  MathBlitzTests
//
//  Created by Codex on 11/10/25.
//

import XCTest
@testable import MathBlitz

final class IdentityTests: XCTestCase {
    func testEmojitarPaletteCountMatchesSpecification() {
        XCTAssertEqual(Emojitar.colorPalette.count, 9)
        XCTAssertEqual(Emojitar.emojiPalette.count, 12)
    }
    
    func testPlayerProfilePreferredModeRoundTrip() throws {
        var profile = PlayerProfile.fresh(
            id: "abc",
            displayName: "Test Pilot",
            emojitar: .init(emoji: "🚀", colorHex: "#3B82F6"),
            mode: .kids
        )
        profile.preferredMode = .adults
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(PlayerProfile.self, from: data)
        XCTAssertEqual(decoded.preferredMode, .adults)
    }
    
    func testAnswerValidatorHonorsEarliestSubmission() {
        let earlier = Date().addingTimeInterval(-5)
        let later = Date()
        let answers = [
            MultiplayerRound.AnswerSubmission(id: "p1", playerId: "p1", value: 12, isCorrect: true, submittedAt: later),
            MultiplayerRound.AnswerSubmission(id: "p2", playerId: "p2", value: 12, isCorrect: true, submittedAt: earlier),
            MultiplayerRound.AnswerSubmission(id: "p3", playerId: "p3", value: 10, isCorrect: false, submittedAt: earlier)
        ]
        
        let winner = AnswerValidator.firstCorrectPlayerId(from: answers)
        XCTAssertEqual(winner, "p2")
    }
}
