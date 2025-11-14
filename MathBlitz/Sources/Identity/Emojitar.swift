//
//  Emojitar.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct Emojitar: Equatable, Codable {
    var emoji: String
    var colorHex: String
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    static let colorPalette: [String] = [
        "#EF4444", "#F59E0B", "#FCD34D",
        "#10B981", "#3B82F6", "#6366F1",
        "#8B5CF6", "#EC4899", "#14B8A6"
    ]
    
    static let emojiPalette: [String] = [
        "⚡️","🚀","🔥","🧠","🐢","😎","🦖",
        "🍀","🎯","💎","🏁","📚","🕹️"
    ]
    
    static let `default` = Emojitar(
        emoji: emojiPalette.first ?? "🚀",
        colorHex: colorPalette.first ?? "#3B82F6"
    )
}
