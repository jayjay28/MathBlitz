//
//  FlowLogger.swift
//  MathBlitz
//
//  Created by ChatGPT on 11/11/25.
//

import Foundation

enum FlowLogger {
    static func trace(_ message: @autoclosure () -> String) {
#if DEBUG
        print("🌀 Flow:", message())
#endif
    }
}


