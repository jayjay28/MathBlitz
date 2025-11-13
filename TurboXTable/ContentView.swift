//
//  ContentView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gameViewModel = GameViewModel()
    @StateObject private var leaderboardViewModel = LeaderboardViewModel()
    @State private var showingSettings = false
    @State private var showingLeaderboard = false
    
    var body: some View {
        Group {
            switch appState.flow {
            case .loading:
                LoadingView()
            case .onboarding:
                OnboardingView(onComplete: appState.completeOnboarding)
            case .gameplay:
                GameSceneView(
                    viewModel: gameViewModel,
                    onSettingsTapped: { showingSettings = true },
                    onLeaderboardTapped: { showingLeaderboard = true },
                    onMultiplayerTapped: { appState.presentMultiplayerSetup() }
                )
                .sheet(isPresented: $showingSettings) {
                    if let profile = appState.profile {
                        SettingsView(profile: profile,
                                     onSave: { updated in
                                         appState.updateProfile(updated)
                                         gameViewModel.updateGameMode(updated.preferredMode)
                                     },
                                     onSignOut: {
                                         showingSettings = false
                                         appState.signOut()
                                     })
                        .presentationDetents([.medium, .large])
                    }
                }
                .sheet(isPresented: $showingLeaderboard) {
                    LeaderboardView(viewModel: leaderboardViewModel)
                }
            case let .multiplayerSetup(code):
                MultiplayerSessionSetupView(
                    initialCode: code,
                    onHost: { code in
                        let mode = appState.profile?.preferredMode ?? .kids
                        appState.hostMultiplayerSession(code: code, mode: mode)
                    },
                    onJoin: { appState.joinMultiplayerSession(code: $0) },
                    onCancel: { appState.cancelMultiplayerSetup() }
                )
            case let .multiplayer(gameId, isHost):
                MultiplayerGameView(gameId: gameId,
                                    isHost: isHost,
                                    onExit: { appState.exitMultiplayer() })
                    .environmentObject(appState)
            }
        }
        .onAppear {
            FlowLogger.trace("ContentView appeared with flow \(appState.flow)")
            if let mode = appState.profile?.preferredMode {
                gameViewModel.updateGameMode(mode)
            }
        }
        .onChange(of: appState.profile?.preferredMode) { mode in
            if let mode {
                gameViewModel.updateGameMode(mode)
            }
        }
        .overlay(alignment: .top) {
            if let toast = appState.toastMessage {
                ToastBanner(message: toast)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let invite = appState.invites.first {
                InviteBanner(invite: invite,
                             accept: {
                                 appState.joinMultiplayerSession(code: invite.gameId)
                                 Task { await InviteService.shared.updateInvite(invite.id, status: .accepted) }
                             },
                             decline: {
                                 Task { await InviteService.shared.updateInvite(invite.id, status: .declined) }
                             })
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: appState.toastMessage) { message in
            guard message != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    appState.dismissToast()
                }
            }
        }
        .onChange(of: appState.flow) { newFlow in
            FlowLogger.trace("App flow changed → \(newFlow)")
        }
    }
}

private struct ToastBanner: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(radius: 10)
    }
}

private struct InviteBanner: View {
    var invite: MultiplayerInvite
    var accept: () -> Void
    var decline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(invite.fromName) invited you!")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Session \(invite.gameId)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Button(action: decline) {
                Text("Later")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            Button(action: accept) {
                Text("Jump in")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .shadow(radius: 12)
    }
}
