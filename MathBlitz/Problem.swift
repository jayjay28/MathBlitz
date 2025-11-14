//
//  Problem.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

struct Problem: Equatable {
    let a: Int
    let b: Int
    var answer: Int { a * b }
    
    static func random(range: ClosedRange<Int> = 2...12) -> Problem {
        Problem(a: Int.random(in: range), b: Int.random(in: range))
    }
}
