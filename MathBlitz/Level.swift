//
//  Level.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

struct Level {
    let levelNumber: Int
    let numberRange: ClosedRange<Int>
    let gameDuration: TimeInterval
    let questionsPerLevel: Int
}
