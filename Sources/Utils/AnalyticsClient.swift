//
//  AnalyticsClient.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum AnalyticsEvent {
    case emojitarSelected(emoji: String, colorHex: String)
    case firstCorrect(playerId: String, roundId: String, latency: TimeInterval)
    case roundCompleted(gameId: String, duration: TimeInterval)
    
    var name: String {
        switch self {
        case .emojitarSelected: return "emojitar_selected"
        case .firstCorrect: return "first_correct"
        case .roundCompleted: return "round_completed"
        }
    }
    
    var payload: [String: Any] {
        switch self {
        case let .emojitarSelected(emoji, colorHex):
            return ["emoji": emoji, "color": colorHex]
        case let .firstCorrect(playerId, roundId, latency):
            return ["playerId": playerId,
                    "roundId": roundId,
                    "latencyMs": Int(latency * 1000)]
        case let .roundCompleted(gameId, duration):
            return ["gameId": gameId,
                    "durationMs": Int(duration * 1000)]
        }
    }
}

enum AnalyticsClient {
    static func track(event: AnalyticsEvent) {
        #if DEBUG
        print("Analytics:", event.name, event.payload)
        #endif
        FlowLogger.trace("Analytics track \(event.name) payload=\(event.payload)")
    }
}
