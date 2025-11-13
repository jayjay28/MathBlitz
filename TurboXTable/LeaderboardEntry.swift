//
//  LeaderboardEntry.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let displayName: String
    let score: Int
    let mode: GameMode
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "playerId"
        case displayName
        case score
        case mode
        case updatedAt
    }
    
    init(id: String, displayName: String, score: Int, mode: GameMode, updatedAt: Date) {
        self.id = id
        self.displayName = displayName
        self.score = score
        self.mode = mode
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modeString = try container.decode(String.self, forKey: .mode)
        guard let decodedMode = GameMode(rawValue: modeString) else {
            throw DecodingError.dataCorruptedError(forKey: .mode,
                                                   in: container,
                                                   debugDescription: "Unknown mode \(modeString)")
        }
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        displayName = try container.decode(String.self, forKey: .displayName)
        score = try container.decode(Int.self, forKey: .score)
        mode = decodedMode
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(score, forKey: .score)
        try container.encode(mode.rawValue, forKey: .mode)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
