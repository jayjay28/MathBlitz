//
//  AmbientSoundToggleButton.swift
//  MathBlitz
//
//  Created by Codex on 11/15/25.
//

import SwiftUI
import UIKit

struct AmbientSoundToggleButton: View {
    @AppStorage(SoundEffectPlayer.ambientLoopMutedDefaultsKey) private var isMuted = true
    
    var body: some View {
        Button(action: toggle) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
                .background(.black.opacity(0.35))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel(isMuted ? "Unmute spooky soundtrack" : "Mute spooky soundtrack")
        .accessibilityHint("Toggles the looping trick or treat tune")
    }
    
    private func toggle() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        isMuted.toggle()
        SoundEffectPlayer.shared.setAmbientLoopMuted(isMuted)
        if !isMuted {
            SoundEffectPlayer.shared.ensureAmbientLoopRunning()
        }
    }
}

struct AmbientSoundToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            AmbientSoundToggleButton()
        }
    }
}
