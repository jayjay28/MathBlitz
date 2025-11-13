//
//  SessionCodeGenerator.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum SessionCodeGenerator {
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    
    static func newCode(length: Int = 5) -> String {
        guard length > 0 else { return "PLAY" }
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
