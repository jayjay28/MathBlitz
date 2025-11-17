//
//  OnboardingEmojitarView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingEmojitarView: View {
    @Binding var emojitar: Emojitar
    var showsEmbeddedSaveButton: Bool
    var onSave: (Emojitar) -> Void
    
    @State private var isPreviewCelebrating: Bool = false
    
    private let emojiColumns = [GridItem(.adaptive(minimum: 48, maximum: 64), spacing: 12, alignment: .center)]
    private let colorColumns = [GridItem(.adaptive(minimum: 40, maximum: 52), spacing: 12)]
    
    init(
        emojitar: Binding<Emojitar>,
        showsEmbeddedSaveButton: Bool = true,
        onSave: @escaping (Emojitar) -> Void
    ) {
        _emojitar = emojitar
        self.showsEmbeddedSaveButton = showsEmbeddedSaveButton
        self.onSave = onSave
    }
    
    var body: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 650
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompactHeight ? 18 : 28) {
                    EmojitarBadge(
                        emoji: emojitar.emoji,
                        color: Color(hex: emojitar.colorHex) ?? .blue,
                        size: isCompactHeight ? .lg : .xl,
                        ring: true,
                        glow: true,
                        highlight: isPreviewCelebrating
                    )
                    .onTapGesture {
                        celebrate()
                    }
                    .accessibilityLabel("Preview emojitar \(emojitar.emoji)")
                    .padding(.top, isCompactHeight ? 4 : 10)
                    
                    emojiPicker
                    colorPicker
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, isCompactHeight ? 18 : 28)
                .padding(.top, isCompactHeight ? 16 : 28)
                .padding(.bottom, showsEmbeddedSaveButton ? 120 : 32)
            }
            .accessibilityElement(children: .contain)
            .safeAreaInset(edge: .bottom) {
                if showsEmbeddedSaveButton {
                    Button(action: save) {
                        Text("Save my vibe")
                            .font(.bobaland(size: 28))
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSave ? Color.white : Color.white.opacity(0.35))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, isCompactHeight ? 18 : 28)
                    .padding(.bottom, 8)
                    .background(Color.clear)
                }
            }
        }
    }
    
    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emoji")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            LazyVGrid(columns: emojiColumns, spacing: 10) {
                ForEach(Emojitar.emojiPalette, id: \.self) { emoji in
                    Button {
                        selectEmoji(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 52, height: 52)
                            .scaleEffect(emoji == emojitar.emoji ? 1.2 : 1.0)
                            .opacity(emoji == emojitar.emoji ? 1.0 : 0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Emoji \(emoji)")
                }
            }
        }
    }
    
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            LazyVGrid(columns: colorColumns, spacing: 12) {
                ForEach(Emojitar.colorPalette, id: \.self) { hex in
                    Button {
                        selectColor(hex)
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .white)
                            .frame(width: 42, height: 42)
                            .overlay {
                                if hex == emojitar.colorHex {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .scaleEffect(1.1)
                                }
                            }
                            .shadow(color: Color(hex: hex)?.opacity(0.4) ?? .clear,
                                    radius: hex == emojitar.colorHex ? 8 : 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                }
            }
        }
    }
    
    private var canSave: Bool {
        !emojitar.emoji.isEmpty && !emojitar.colorHex.isEmpty
    }
    
    private func selectEmoji(_ emoji: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            emojitar.emoji = emoji
        }
        SoundEffectPlayer.shared.playOnboardingSelect()
        celebrate(light: true)
    }
    
    private func selectColor(_ hex: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            emojitar.colorHex = hex
        }
        SoundEffectPlayer.shared.playOnboardingSelect()
        celebrate(light: true)
    }
    
    private func save() {
        guard canSave else { return }
        celebrate()
        onSave(emojitar)
    }
    
    private func celebrate(light: Bool = false) {
        guard !light else {
            #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
            return
        }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        withAnimation(.easeInOut(duration: 0.6)) {
            isPreviewCelebrating.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            isPreviewCelebrating = false
        }
    }
}

#if DEBUG
struct OnboardingEmojitarView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingEmojitarView(emojitar: .constant(.default)) { _ in }
            .preferredColorScheme(.dark)
            .previewDisplayName("Emojitar Picker")
    }
}
#endif
