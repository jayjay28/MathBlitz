//
//  AppState.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation
import Combine
import FirebaseAuth

enum AppFlow: Equatable {
    case loading
    case onboarding
    case gameplay
    case multiplayerSetup(code: String)
    case multiplayer(gameId: String, isHost: Bool)
}

@MainActor
final class AppState: ObservableObject {
    @Published var flow: AppFlow = .loading
    @Published var profile: PlayerProfile?
    @Published var toastMessage: String?
    @Published var invites: [MultiplayerInvite] = []
    @Published var onlinePlayerCount: Int = 0
    
    private let profileStore = PlayerProfileStore.shared
    private let inviteService = InviteService.shared
    private let presenceService = PresenceService.shared
    private var cancellables: Set<AnyCancellable> = []
    private var pendingMultiplayerCode: String = SessionCodeGenerator.newCode()
    
    init() {
        FlowLogger.trace("AppState init → starting anonymous auth bootstrap")
        profileStore.$profile
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                self?.profile = profile
                self?.handleProfileChange(profile)
            }
            .store(in: &cancellables)
        
        inviteService.$pendingInvites
            .receive(on: RunLoop.main)
            .sink { [weak self] invites in
                self?.invites = invites
            }
            .store(in: &cancellables)
        
        profileStore.$lastError
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.toastMessage = "Offline — local profile used."
            }
            .store(in: &cancellables)
        
        presenceService.$onlineCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.onlinePlayerCount = count
            }
            .store(in: &cancellables)
        
        if DebugDefaults.isTestGameStartNotifierEnabled {
            NotificationCenter.default.publisher(for: .testGameStartBroadcastReceived)
                .compactMap { $0.object as? TestGameStartEvent }
                .receive(on: RunLoop.main)
                .sink { [weak self] event in
                    self?.toastMessage = "Test mode: \(event.playerName) started \(event.mode.displayName)"
                }
                .store(in: &cancellables)
        }
        
        Task { await initializeFlow() }
    }
    
    init(previewProfile: PlayerProfile, initialFlow: AppFlow = .gameplay) {
        self.profile = previewProfile
        self.flow = initialFlow
        FlowLogger.trace("AppState preview init → \(previewProfile.displayName)")
        handleProfileChange(previewProfile)
    }
    
    func completeOnboarding(displayName: String, emojitar: Emojitar, mode: GameMode) {
        FlowLogger.trace("Onboarding complete for \(displayName) with mode \(mode.rawValue)")
        Task {
            do {
                try await profileStore.upsertProfile(
                    displayName: displayName,
                    emojitar: emojitar,
                    preferredMode: mode
                )
                flow = .gameplay
            } catch {
                FlowLogger.trace("Onboarding profile save failed → \(error.localizedDescription)")
                flow = .gameplay
            }
        }
    }
    
    func updateProfile(_ profile: PlayerProfile) {
        FlowLogger.trace("Updating profile for \(profile.displayName)")
        Task {
            do {
                try await profileStore.upsertProfile(
                    displayName: profile.displayName,
                    emojitar: profile.emojitar,
                    preferredMode: profile.preferredMode
                )
            } catch {
                FlowLogger.trace("Profile update failed → \(error.localizedDescription)")
            }
        }
    }
    
    func signOut() {
        FlowLogger.trace("Signing out current player")
        do {
            try Auth.auth().signOut()
        } catch {
#if DEBUG
            print("Sign out failed: \(error.localizedDescription)")
#endif
        }
        profileStore.clear()
        profile = nil
        presenceService.stopTracking()
        flow = .loading
        inviteService.stopListening()
        Task {
            await initializeFlow()
        }
    }
    
    private func initializeFlow() async {
        do {
            try await ensureAnonymousAuth()
            FlowLogger.trace("Anonymous auth ready")
            profileStore.hydrate()
            if shouldForceOnboarding() {
                FlowLogger.trace("Debug override forcing onboarding flow")
                flow = .onboarding
                return
            }
            if let storedProfile = profileStore.profile,
               let userId = Auth.auth().currentUser?.uid {
                profile = storedProfile
                handleProfileChange(storedProfile)
                inviteService.startListening(for: userId)
                flow = .gameplay
                FlowLogger.trace("Profile restored → gameplay")
            } else {
                flow = .onboarding
                FlowLogger.trace("No profile found → onboarding")
            }
        } catch {
            FlowLogger.trace("Anonymous auth failed → \(error.localizedDescription)")
            flow = .onboarding
        }
    }
    
    private func ensureAnonymousAuth() async throws {
        if Auth.auth().currentUser != nil { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func dismissToast() {
        toastMessage = nil
    }
    
    func presentMultiplayerSetup() {
        pendingMultiplayerCode = SessionCodeGenerator.newCode()
        flow = .multiplayerSetup(code: pendingMultiplayerCode)
    }
    
    func cancelMultiplayerSetup() {
        flow = .gameplay
    }
    
    func hostMultiplayerSession(code: String, mode: GameMode) {
        let normalized = normalizeSessionCode(code)
        Task {
            await MultiplayerSyncService.shared.resetGameDocument(gameId: normalized, mode: mode)
            await MainActor.run {
                inviteService.stopListening()
                flow = .multiplayer(gameId: normalized, isHost: true)
            }
        }
    }
    
    func joinMultiplayerSession(code: String) {
        let normalized = normalizeSessionCode(code)
        inviteService.stopListening()
        flow = .multiplayer(gameId: normalized, isHost: false)
    }
    
    func exitMultiplayer() {
        if let userId = Auth.auth().currentUser?.uid {
            inviteService.startListening(for: userId)
        }
        flow = .gameplay
    }

    
    private func normalizeSessionCode(_ code: String) -> String {
        let filtered = code.uppercased().filter { $0.isLetter || $0.isNumber }
        return filtered.isEmpty ? SessionCodeGenerator.newCode() : filtered
    }
    
    private func shouldForceOnboarding() -> Bool {
#if DEBUG
        return UserDefaults.standard.bool(forKey: DebugDefaults.forceOnboardingOnLaunchKey)
#else
        return false
#endif
    }
    
    private func handleProfileChange(_ profile: PlayerProfile?) {
        let wantsAlerts = DebugDefaults.isTestGameStartNotifierEnabled && (profile?.alertClyonGameStart ?? false)
        TestGameStartNotifier.shared.updateSubscriptionState(enabled: wantsAlerts)
        CloudKitNotificationManager.shared.updateSubscription(for: profile)
        guard let profile else {
            presenceService.stopTracking()
            return
        }
        presenceService.startTracking(profile: profile)
    }
}
