//
//  GameMode.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case kids
    case adults
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .kids: return "Kids"
        case .adults: return "Adults"
        }
    }
    
    var subtitle: String {
        switch self {
        case .kids: return "Gentle pacing, friendlier numbers."
        case .adults: return "Faster rounds, bigger factors."
        }
    }
    
    var firestoreDocument: String {
        rawValue
    }
}
