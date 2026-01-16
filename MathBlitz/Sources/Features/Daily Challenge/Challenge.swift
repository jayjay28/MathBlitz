//
//  Challenge.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 12/5/25.
//

import Foundation
import FirebaseFirestore

// This struct models the data for a single daily challenge fetched from Firestore.
struct Challenge: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var difficulty: String
    var tags: [String]
    var date_scheduled: String
    var prompt: String
    var answer_type: String
    var correct_answer: Double // Use Double to accommodate potential decimals in hard mode
    var time_limit_seconds: Int
    
    // Nested structs for clarity
    struct NumpadConfig: Codable {
        var max_digits: Int
        var allow_negative: Bool
        var allow_decimal: Bool
    }
    var numpad: NumpadConfig

    struct MultipleChoiceConfig: Codable {
        var enabled: Bool
        var choices: [Double]
        var correct_choice_index: Int
    }
    var multiple_choice: MultipleChoiceConfig
    
    struct ScoringConfig: Codable {
        var base_points: Int
    }
    var scoring: ScoringConfig
    
    var explanation: String
}
