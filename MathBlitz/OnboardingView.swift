//
//  OnboardingView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: (String, Emojitar, GameMode) -> Void
    
    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var mode: GameMode = .kids
    @State private var emojitar: Emojitar = .default
    
    var body: some View {
        VStack(spacing: 28) {
            Text(title)
                .font(.bobaland(size: 44))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            card
                .padding(.horizontal, 24)
            
            controlBar
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
    
    private var title: String {
        switch step {
        case 0: return "Welcome, Puzzle Master!"
        case 1: return "What do friends call you?"
        case 2: return "Choose your challenge"
        default: return "Pick your vibe 👇"
        }
    }
    
    @ViewBuilder
    private var card: some View {
        VStack(spacing: 20) {
            switch step {
            case 0:
                Text("Let's get you set up so you can track your progress.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            case 1:
                VStack(spacing: 8) {
                    TextField("Type your name", text: $name)
                        .font(.bobaland(size: 28))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
            case 2:
                VStack(spacing: 16) {
                    ForEach(GameMode.allCases) { option in
                        Button(action: {
                            FlowLogger.trace("Onboarding mode selected → \(option.rawValue)")
                            mode = option
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(option.displayName)
                                        .font(.bobaland(size: 32))
                                        .foregroundColor(.white)
                                    Text(option.subtitle)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                Spacer()
                                if option == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 26))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(option == mode ? 0.25 : 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                }
            default:
                OnboardingEmojitarView(
                    emojitar: $emojitar,
                    showsEmbeddedSaveButton: false
                ) { _ in }
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .background(step < 2 ? Color.clear : Color.white.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
    
    private func advance() {
        FlowLogger.trace("Onboarding advance from step \(step)")
        if step < 3 {
            step += 1
            FlowLogger.trace("Onboarding moved to step \(step)")
        } else {
            finish()
        }
    }
    
    private func finish() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Puzzle Master" : trimmedName
        FlowLogger.trace("Onboarding finished → name: \(finalName), mode: \(mode.rawValue)")
        onComplete(finalName, emojitar, mode)
    }
    
    private var controlBar: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    FlowLogger.trace("Onboarding retreat from step \(step)")
                    step -= 1
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            if step < 3 {
                Button("Next", action: advance)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(step == 1 ? name.trimmingCharacters(in: .whitespaces).isEmpty : false)
            } else {
                Button("Save my vibe", action: finish)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 36)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bobaland(size: 24))
            .foregroundColor(.purple)
            .padding(.horizontal, 36)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: { _, _, _ in })
            .previewDisplayName("Onboarding Flow")
    }
}
#endif
