//
//  PlayerProfile.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

struct PlayerProfile: Equatable, Codable, Identifiable {
    var id: String
    var displayName: String
    var emojitar: Emojitar
    var createdAt: Date
    var updatedAt: Date
    private var preferredModeRaw: String?
    
    init(
        id: String,
        displayName: String,
        emojitar: Emojitar,
        createdAt: Date,
        updatedAt: Date,
        preferredModeRaw: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.emojitar = emojitar
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.preferredModeRaw = preferredModeRaw
    }
    
    var preferredMode: GameMode {
        get {
            GameMode(rawValue: preferredModeRaw ?? GameMode.kids.rawValue) ?? .kids
        }
        set {
            preferredModeRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

extension PlayerProfile {
    static func fresh(
        id: String,
        displayName: String,
        emojitar: Emojitar,
        mode: GameMode,
        createdAt: Date = Date()
    ) -> PlayerProfile {
        PlayerProfile(
            id: id,
            displayName: displayName,
            emojitar: emojitar,
            createdAt: createdAt,
            updatedAt: createdAt,
            preferredModeRaw: mode.rawValue
        )
    }
}
