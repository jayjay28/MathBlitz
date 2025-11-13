//
//  MultiplayerInvite.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case completed
}

struct MultiplayerInvite: Identifiable, Codable, Equatable {
    var id: String
    var fromPlayerId: String
    var fromName: String
    var toPlayerId: String
    var toName: String
    var gameId: String
    var createdAt: Date
    var status: InviteStatus
}
