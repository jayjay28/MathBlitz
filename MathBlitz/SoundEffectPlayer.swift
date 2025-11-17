//
//  SoundEffectPlayer.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation
import AVFoundation
import UIKit

final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()
    static let ambientLoopMutedDefaultsKey = "SoundEffectPlayer.ambientLoopMuted"
    
    private let selectSoundNames: [String] = (1...9).map { String(format: "select_%03d", $0) }
    private let blockedSoundName = "error_003"
    private let ambientSoundName = "trick or treat"
    private let readySoundName = "question_003"
    private let countdownSoundName = "select_001"
    private let onboardingSelectSoundName = "select_003"
    private let ambientVolume: Float = 0.18
    private var nextSelectIndex = 0
    private var players: [String: AVAudioPlayer] = [:]
    private var ambientPlayer: AVAudioPlayer?
    private let queue = DispatchQueue(label: "SoundEffectPlayer.queue")
    private var didConfigureAudioSession = false
    private var ambientMuted: Bool
    
    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.ambientLoopMutedDefaultsKey) as? Bool {
            ambientMuted = stored
        } else {
            ambientMuted = true
            UserDefaults.standard.set(true, forKey: Self.ambientLoopMutedDefaultsKey)
        }
    }
    
    func playNextSelect() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.selectSoundNames.isEmpty else {
                FlowLogger.trace("No select sound assets found; skipping playback")
                return
            }
            self.ensureAudioSession()
            let name = self.selectSoundNames[self.nextSelectIndex]
            FlowLogger.trace("Preparing to play select sound '\(name)'")
            self.nextSelectIndex = (self.nextSelectIndex + 1) % self.selectSoundNames.count
            self.playSound(named: name)
        }
    }
    
    func playBlocked() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            FlowLogger.trace("Playing blocked interaction sound")
            self.playSound(named: self.blockedSoundName)
        }
    }
    
    func playGlassSound() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            FlowLogger.trace("Playing glass_005 sound")
            self.playSound(named: "glass_005")
        }
    }
    
    func playReadyToggle() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            FlowLogger.trace("Playing ready toggle sound")
            self.playSound(named: self.readySoundName)
        }
    }
    
    func ensureAmbientLoopRunning() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            
            if ambientPlayer == nil {
                guard let asset = NSDataAsset(name: ambientSoundName) else {
                    FlowLogger.trace("Ambient sound asset missing (\(ambientSoundName))")
                    return
                }
                
                do {
                    let player = try AVAudioPlayer(data: asset.data)
                    player.numberOfLoops = -1
                    player.volume = ambientMuted ? 0 : ambientVolume
                    player.prepareToPlay()
                    ambientPlayer = player
                    FlowLogger.trace("Ambient loop prepared for \(ambientSoundName)")
                } catch {
                    FlowLogger.trace("Failed to prepare ambient loop → \(error.localizedDescription)")
                    return
                }
            }
            
            updateAmbientPlaybackState()
        }
    }
    
    func setAmbientLoopMuted(_ muted: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            guard ambientMuted != muted else { return }
            ambientMuted = muted
            UserDefaults.standard.set(muted, forKey: Self.ambientLoopMutedDefaultsKey)
            FlowLogger.trace("Ambient loop mute updated → \(muted ? "ON" : "OFF")")
            updateAmbientPlaybackState()
        }
    }
    
    func playCountdownTick() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            FlowLogger.trace("Playing countdown tick sound")
            self.playSound(named: self.countdownSoundName)
        }
    }
    
    func playOnboardingSelect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureAudioSession()
            FlowLogger.trace("Playing onboarding select sound")
            self.playSound(named: self.onboardingSelectSoundName)
        }
    }
    
    private func playSound(named name: String) {
        if let player = players[name] {
            player.currentTime = 0
            player.play()
            FlowLogger.trace("Reusing cached sound '\(name)'")
            return
        }
        
        guard let asset = NSDataAsset(name: name) else {
            FlowLogger.trace("Sound asset missing for \(name)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(data: asset.data)
            player.prepareToPlay()
            player.play()
            players[name] = player
            FlowLogger.trace("Created new player and started sound '\(name)'")
        } catch {
            FlowLogger.trace("Failed to play sound \(name) → \(error.localizedDescription)")
        }
    }
    
    private func ensureAudioSession() {
        guard !didConfigureAudioSession else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            didConfigureAudioSession = true
            FlowLogger.trace("Sound audio session configured (ambient + mixWithOthers)")
        } catch {
            FlowLogger.trace("Failed to configure audio session → \(error.localizedDescription)")
        }
    }
    
    private func updateAmbientPlaybackState() {
        guard let player = ambientPlayer else { return }
        
        if ambientMuted {
            if player.isPlaying {
                player.pause()
                player.currentTime = 0
            }
            player.volume = 0
        } else {
            player.volume = ambientVolume
            if !player.isPlaying {
                player.play()
            }
        }
    }
}
