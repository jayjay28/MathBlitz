//
//  EmojitarBadge.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct EmojitarBadge: View {
    enum Size: CaseIterable {
        case xs, sm, md, lg, xl, xxl
        
        var diameter: CGFloat {
            switch self {
            case .xs: return 28
            case .sm: return 36
            case .md: return 48
            case .lg: return 64
            case .xl: return 84
            case .xxl: return 120
            }
        }
    }
    
    var emoji: String
    var color: Color
    var size: Size
    var ring: Bool = false
    var glow: Bool = false
    var highlight: Bool = false
    
    @State private var pulsePhase: Bool = false
    
    private var diameter: CGFloat { size.diameter }
    private var fontSize: CGFloat { diameter * 0.55 }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .clipShape(Circle())
                .overlay {
                    if ring {
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: diameter * 0.06)
                    }
                }
                .shadow(color: glow ? color.opacity(0.35) : .clear,
                        radius: glow ? diameter * 0.22 : 0,
                        x: 0,
                        y: 0)
            Text(emoji)
                .font(.system(size: fontSize))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityHidden(true)
                .id(emoji)
                .transition(.scale.combined(with: .opacity))
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(highlight ? (pulsePhase ? 1.12 : 1.0) : 1.0)
        .onAppear {
            guard highlight else { return }
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
        .onChange(of: highlight) { isHighlighting in
            if isHighlighting {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            } else {
                pulsePhase = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emoji) emojitar badge")
        .accessibilityHint(ring ? "Currently highlighted" : "Player identity badge")
    }
}
