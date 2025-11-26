//
//  Color+Hex.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init?(hex: String, alpha: Double = 1.0) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
    
    static func primaryContrast(for color: Color) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = (0.299 * r + 0.587 * g + 0.114 * b)
        return luminance > 0.55 ? .black : .white
        #else
        return .white
        #endif
    }
    
    func mix(with other: Color, by amount: Double) -> Color {
        #if canImport(UIKit)
        let selfUIColor = UIColor(self)
        let otherUIColor = UIColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        selfUIColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherUIColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let clampedAmount = max(0, min(1, amount))
        let r = r1 + (r2 - r1) * clampedAmount
        let g = g1 + (g2 - g1) * clampedAmount
        let b = b1 + (b2 - b1) * clampedAmount
        let a = a1 + (a2 - a1) * clampedAmount
        
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
        #else
        return self
        #endif
    }
}
