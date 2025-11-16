//
//  NumpadView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct NumpadView: View {
    var rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]
    
    var buttonSize: CGFloat = 80
    var digitFontSize: CGFloat = 44
    var symbolFontSize: CGFloat = 28
    var verticalSpacing: CGFloat = 12
    var horizontalSpacing: CGFloat = 12
    var foregroundForButton: (String, Bool) -> Color = { _, _ in .white }
    var isButtonEnabled: (String) -> Bool = { _ in true }
    var onDisabledPress: (() -> Void)?
    var onPress: (String) -> Void
    
    var body: some View {
        VStack(spacing: verticalSpacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(row, id: \.self) { value in
                        let isDigit = value.allSatisfy(\.isNumber)
                        let enabled = isButtonEnabled(value)
                        Button {
                            guard enabled else {
                                FlowLogger.trace("Numpad '\(value)' pressed while disabled")
                                onDisabledPress?()
                                return
                            }
                            FlowLogger.trace("Numpad '\(value)' pressed → triggering glass_005 sound")
                            SoundEffectPlayer.shared.playGlassSound()
                            onPress(value)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                
                                Text(value)
                                    .font(isDigit ? .bobaland(size: digitFontSize) :
                                            .system(size: symbolFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(foregroundForButton(value, enabled))
                            }
                            .frame(width: buttonSize, height: buttonSize)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
