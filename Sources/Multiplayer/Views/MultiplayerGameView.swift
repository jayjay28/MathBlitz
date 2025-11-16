//
//  MultiplayerGameView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI
import Combine

struct MultiplayerGameView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var syncService = MultiplayerSyncService.shared
    @StateObject private var multiplayerGameViewModel = GameViewModel()
    @State private var roundTimerTask: Task<Void, Never>?
    @State private var didLogResultForRound = false
    @State private var isReturningToLobby = false
    private let roundDuration: TimeInterval = 60
    @State private var timerTick = Date()
    private let uiTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let gameId: String
    let isHost: Bool
    let onExit: () -> Void
    
    var body: some View {
        Group {
            switch syncService.game.phase {
            case .lobby:
                LobbyView(
                    players: syncService.game.players,
                    localPlayerId: appState.profile?.id,
                    isHost: isHost,
                    maxPlayers: syncService.capacity,
                    sessionCode: gameId,
                    onReadyToggle: { isReady in
                        if let profile = appState.profile {
                            Task { await syncService.toggleReady(isReady: isReady, profile: profile) }
                        }
                    },
                    onStartMatch: {
                        startMatchIfPossible()
                    },
                    onExit: {
                        syncService.detach()
                        onExit()
                    }
                )
            case let .countdown(remaining):
                CountdownView(players: syncService.game.players, secondsRemaining: Int(remaining))
            case .round:
                if let round = syncService.game.currentRound {
                    MultiplayerRoundPlayView(
                        round: round,
                        players: syncService.game.players,
                        timeRemaining: timeRemainingSeconds(),
                        onSubmitAnswer: { answer in
                            guard let profile = appState.profile else { return }
                            Task {
                                try? await syncService.submit(answer: answer,
                                                              for: profile,
                                                              roundId: round.id)
                            }
                        },
                        onBack: { onExit() }
                    )
                } else {
                    ProgressView("Loading round…")
                        .foregroundColor(.white)
                }
            case .scoreboard:
                ScoreboardView(
                    players: syncService.game.players,
                    winnerId: syncService.game.winnerId,
                    isHost: isHost,
                    isReturningToLobby: isReturningToLobby,
                    onReturnToLobby: {
                        guard isHost, !isReturningToLobby else { return }
                        isReturningToLobby = true
                        Task {
                            await syncService.returnToLobby()
                            await MainActor.run {
                                isReturningToLobby = false
                            }
                        }
                    },
                    onClose: {
                        syncService.detach()
                        onExit()
                    }
                )
            }
        }
        .onAppear {
            multiplayerGameViewModel.isMultiplayerContext = true
            syncService.setIsLocalHost(isHost)
            syncService.attach(gameId: gameId)
            registerLocalPlayerIfPossible()
        }
        .onDisappear {
            syncService.setIsLocalHost(false)
            syncService.detach()
            cancelRoundTimer()
        }
        .onChange(of: appState.profile?.id) { _ in
            registerLocalPlayerIfPossible()
        }
        .onReceive(uiTimer) { now in
            timerTick = now
        }
        .onChange(of: syncService.game.phase) { phase in
            switch phase {
            case .round:
                didLogResultForRound = false
                startRoundTimerIfNeeded()
            case .scoreboard:
                cancelRoundTimer()
                recordResultsIfNeeded()
            case .lobby:
                cancelRoundTimer()
                didLogResultForRound = false
            default:
                break
            }
        }
    }
    
    private func annotatedPlayers(round: MultiplayerRound) -> [MultiplayerPlayerState] {
        AnswerValidator.annotatePlayers(players: syncService.game.players, round: round)
    }
    
    private func registerLocalPlayerIfPossible() {
        guard let profile = appState.profile else {
            FlowLogger.trace("Multiplayer register skipped → no profile yet")
            return
        }
        Task {
            await syncService.registerPlayerIfNeeded(profile: profile)
        }
    }
    
    private func startMatchIfPossible() {
        guard isHost else {
            FlowLogger.trace("Multiplayer start denied → not host")
            return
        }
        guard let profile = appState.profile else {
            FlowLogger.trace("Multiplayer start denied → missing profile")
            return
        }
        Task {
            await syncService.startMatch(mode: profile.preferredMode)
        }
    }
    
    private func startRoundTimerIfNeeded() {
        guard isHost else { return }
        cancelRoundTimer()
        roundTimerTask = Task { [roundDuration] in
            try? await Task.sleep(nanoseconds: UInt64(roundDuration * 1_000_000_000))
            if !Task.isCancelled {
                await syncService.finishRound()
            }
        }
    }
    
    private func cancelRoundTimer() {
        roundTimerTask?.cancel()
        roundTimerTask = nil
    }
    
    private func recordResultsIfNeeded() {
        guard !didLogResultForRound,
              let localProfile = appState.profile else { return }
        let winnerId = syncService.game.winnerId
        for player in syncService.game.players where player.id != localProfile.id {
            let outcome: MatchOutcome
            if let winnerId {
                if winnerId == localProfile.id {
                    outcome = .win
                } else if winnerId == player.id {
                    outcome = .loss
                } else {
                    outcome = .tie
                }
            } else {
                outcome = .tie
            }
            MultiplayerRecordStore.shared.recordResult(opponent: player.profile, outcome: outcome)
        }
        didLogResultForRound = true
    }
    
    private func timeRemainingSeconds() -> Int {
        guard let start = syncService.game.roundStartedAt else {
            return Int(roundDuration)
        }
        let elapsed = timerTick.timeIntervalSince(start)
        return max(0, Int(roundDuration - elapsed))
    }
}
