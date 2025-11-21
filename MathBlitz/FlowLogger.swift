//
//  FlowLogger.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

struct FlowLogger {
    static func trace(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}
