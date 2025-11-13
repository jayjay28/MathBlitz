//
//  EmojitarBadgeSnapshotTests.swift
//  MathBlitzTests
//
//  Created by Codex on 11/10/25.
//

import XCTest
import SwiftUI
@testable import MathBlitz

@MainActor
final class EmojitarBadgeSnapshotTests: XCTestCase {
    func testBadgeRendersAllSizes() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("Requires iOS 16 APIs")
        }
        
        for size in EmojitarBadge.Size.allCases {
            let badge = EmojitarBadge(
                emoji: "🧠",
                color: Color(hex: "#6366F1") ?? .purple,
                size: size,
                ring: true,
                glow: true
            )
            let renderer = ImageRenderer(content: badge.frame(width: size.diameter, height: size.diameter))
            XCTAssertNotNil(renderer.uiImage, "Renderer should create image for size \(size)")
        }
    }
}
