//
//  NumpadView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

//
//  NumpadView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct AnswerView: View {
    let answer: String
    
    var body: some View {
        Text(answer.isEmpty ? "?" : answer)
            .font(.bobaland(size: 72))
            .foregroundColor(.white)
            .allowsTightening(true)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
    }
}

struct NumpadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NumpadView: View {
    @Binding var userAnswer: String
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]
    
    var foregroundForButton: (String, Bool) -> Color = { _, _ in .white }
    var isButtonEnabled: (String) -> Bool = { _ in true }
    var onDisabledPress: (() -> Void)?
    var onPress: (String) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            AnswerView(answer: userAnswer)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(buttons.flatMap { $0 }, id: \.self) { value in
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
                                .font(isDigit ? .bobaland(size: 44) :
                                        .system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(foregroundForButton(value, enabled))
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(NumpadButtonStyle())
                }
            }
        }
    }
}

