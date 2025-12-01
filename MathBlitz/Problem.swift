//
//  Problem.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

enum OperationType: CaseIterable {
    case add, subtract, multiply
    
    var displayText: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        }
    }
}

struct Problem: Equatable, Hashable {
    let a: Int
    let b: Int
    let operation: OperationType
    
    var answer: Int {
        switch operation {
        case .add: return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        }
    }
    
    static func random(range: ClosedRange<Int> = 2...12, operations: [OperationType]? = nil) -> Problem {
        let op = (operations ?? OperationType.allCases).randomElement()!
        let numA = Int.random(in: range)
        let numB = Int.random(in: range)
        
        if op == .subtract {
            // Ensure answer is not negative
            if numA >= numB {
                return Problem(a: numA, b: numB, operation: op)
            } else {
                return Problem(a: numB, b: numA, operation: op)
            }
        }
        
        return Problem(a: numA, b: numB, operation: op)
    }
}
