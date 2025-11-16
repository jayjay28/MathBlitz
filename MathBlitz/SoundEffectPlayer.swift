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
    
    private let selectSoundNames: [String] = (1...9).map { String(format: "select_%03d", $0) }
    private let blockedSoundName = "error_003"
    private var nextSelectIndex = 0
    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "SoundEffectPlayer.queue")
    private var didConfigureAudioSession = false
    
    private init() {}
    
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
}
