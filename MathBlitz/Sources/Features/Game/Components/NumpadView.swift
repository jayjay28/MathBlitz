//
//  NumpadView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI


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
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
        ["C", "0", "⌫"]
    ]
    
    var backgroundForButton: (String, Bool) -> Color = { _, isEnabled in
        isEnabled ? Color.white.opacity(0.25) : Color.gray.opacity(0.25)
    }
    var foregroundForButton: (String, Bool) -> Color = { _, _ in .white }
    var isButtonEnabled: (String) -> Bool = { _ in true }
    var onDisabledPress: (() -> Void)?
    var onPress: (String) -> Void
    
    var body: some View {
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    SoundEffectPlayer.shared.playGlassSound()
                    onPress(value)
                } label: {
                    GeometryReader { geo in
                        ZStack {
                            Circle()
                                .fill(backgroundForButton(value, enabled))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                            
                            Text(value)
                                .font(isDigit ? .bobaland(size: geo.size.width * 0.5) :
                                        .system(size: geo.size.width * 0.35, weight: .bold, design: .rounded))
                                .foregroundColor(foregroundForButton(value, enabled))
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(NumpadButtonStyle())
            }
        }
    }
}

struct NumpadView_Previews: PreviewProvider {
    static var previews: some View {
        NumpadView(userAnswer: .constant("123")) { _ in }
            .background(Color.blue)
    }
}
