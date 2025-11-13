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
    var onSave: (Emojitar) -> Void
    
    @State private var isPreviewCelebrating: Bool = false
    
    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 16, alignment: .center)]
    
    init(emojitar: Binding<Emojitar>, onSave: @escaping (Emojitar) -> Void) {
        _emojitar = emojitar
        self.onSave = onSave
    }
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 32) {

                    
                    EmojitarBadge(
                        emoji: emojitar.emoji,
                        color: Color(hex: emojitar.colorHex) ?? .blue,
                        size: .xxl,
                        ring: true,
                        glow: true,
                        highlight: isPreviewCelebrating
                    )
                    .onTapGesture {
                        celebrate()
                    }
                    .accessibilityLabel("Preview emojitar \(emojitar.emoji)")
                    .padding(.top, 8)
                    
                    VStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emoji")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(Emojitar.emojiPalette, id: \.self) { emoji in
                                    Button {
                                        selectEmoji(emoji)
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 56, height: 56)
                                            .scaleEffect(emoji == emojitar.emoji ? 1.2 : 1.0)
                                            .opacity(emoji == emojitar.emoji ? 1.0 : 0.7)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Emoji \(emoji)")
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 16)], spacing: 12) {
                                ForEach(Emojitar.colorPalette, id: \.self) { hex in
                                    Button {
                                        selectColor(hex)
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex) ?? .white)
                                            .frame(width: 44, height: 44)
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
                        .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(32)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .accessibilityElement(children: .contain)
        }
    }
    
    private var canSave: Bool {
        !emojitar.emoji.isEmpty && !emojitar.colorHex.isEmpty
    }
    
    private func selectEmoji(_ emoji: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            emojitar.emoji = emoji
        }
        celebrate(light: true)
    }
    
    private func selectColor(_ hex: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            emojitar.colorHex = hex
        }
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
