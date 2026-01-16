//
//  HomeView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI
import FirebaseFirestore

// Data model for users who completed the challenge
struct CompletedUser: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var emojitar: Emojitar
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case displayName
        case emojitar
    }
}


struct HomeView: View {
    @ObservedObject var gameViewModel: GameViewModel
    @Binding var showingSettings: Bool
    @Binding var showingLeaderboard: Bool
    @ObservedObject var appState: AppState
    
    // UI State
    @State private var isMenuOpen = false
    
    // Skills Lab State
    @State private var isStartingGame = false
    @State private var countdownSeconds = 3
    @State private var showStartCountdown = false
    
    // Daily Challenge State
    @State private var showDailyChallengeCountdown = false
    @State private var dailyChallengeCountdownSeconds = 3
    @State private var navigateToTodaysChallenge = false
    @State private var dailyChallengeResult: String? = nil
    @State private var completedUsers: [CompletedUser] = []

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                homeContent
                
                menuButtonLayer
                
                if isMenuOpen {
                    Color.black.opacity(0.25).ignoresSafeArea().onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isMenuOpen = false }
                    }
                    SideMenuView(
                        onLeaderboard: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isMenuOpen = false }
                            showingLeaderboard = true
                        },
                        onSettings: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isMenuOpen = false }
                            showingSettings = true
                        },
                        onMultiplayer: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isMenuOpen = false }
                            appState.presentMultiplayerSetup()
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
            .overlay(countdownOverlay)
            .background(
                NavigationLink(
                    destination: GameSceneView(
                        viewModel: gameViewModel,
                        onSettingsTapped: { showingSettings = true },
                        onLeaderboardTapped: { showingLeaderboard = true },
                        onMultiplayerTapped: { appState.presentMultiplayerSetup() }
                    ),
                    isActive: $isStartingGame,
                    label: { EmptyView() }
                ).hidden()
            )
            .navigationDestination(isPresented: $navigateToTodaysChallenge) {
                TodaysChallengeView() { correct, total in
                    self.dailyChallengeResult = "\(correct)/\(total)"
                    self.navigateToTodaysChallenge = false // Dismiss the view
                }
                .environmentObject(appState)
            }
            .onAppear {
                isStartingGame = false
                showStartCountdown = false
                navigateToTodaysChallenge = false
                fetchCompletedUsers()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var homeContent: some View {
        VStack(spacing: 24) {
            Text("MathBlitz")
                .font(.bobaland(size: 40))
                .foregroundColor(.white)
            
            // Group the mode selection buttons
            VStack(spacing: 16) {
                Button(action: startSkillLab) {
                    HStack(spacing: 20) {
                        Image(systemName: "person.fill").font(.system(size: 32, weight: .medium))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Skills Lab").font(.bobaland(size: 32))
                            Text("Train your brain").font(.system(size: 16, weight: .medium, design: .rounded)).opacity(0.7)
                        }
                    }
                    .padding(.horizontal, 24)
                }.buttonStyle(PrimaryGameModeButtonStyle())
                
                Button(action: { appState.presentMultiplayerSetup() }) {
                    HStack(spacing: 20) {
                        Image(systemName: "person.3.fill").font(.system(size: 32, weight: .medium))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Multiplayer").font(.bobaland(size: 32))
                            Text("Play with friends").font(.system(size: 16, weight: .medium, design: .rounded)).opacity(0.7)
                        }
                    }
                    .padding(.horizontal, 24)
                }.buttonStyle(PrimaryGameModeButtonStyle())
            }
            
            dailyChallengeSection
        }
        .padding(20)
        .frame(maxWidth: 700, alignment: .center)
    }
    
    private var dailyChallengeSection: some View {
        //no background colors ever!
        VStack(spacing: 24) {
            if let result = dailyChallengeResult {
                Text("Today's Result: \(result)")
                    .font(.headline).foregroundColor(.white).padding().background(Color.white.opacity(0.1)).cornerRadius(10)
            } else {
                // Only show the unlock view if the challenge hasn't been completed yet
                DailyChallengeView(showCountdown: $showDailyChallengeCountdown, countdownSeconds: $dailyChallengeCountdownSeconds, onUnlock: startDailyChallenge)
            }
            
            if !completedUsers.isEmpty {
                completedUsersView
            }
        }
    }

    private var completedUsersView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Perfect Scores Today! 🎉").font(.headline).foregroundColor(.white).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(completedUsers) { user in
                        VStack {
                            EmojitarBadge(emoji: user.emojitar.emoji, color: Color(hex: user.emojitar.colorHex) ?? .white, size: .md)
                            Text(user.displayName).font(.caption).foregroundColor(.white).lineLimit(1)
                        }.frame(width: 80)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var countdownOverlay: some View {
        Group {
            if showStartCountdown { CountdownView(players: [], secondsRemaining: countdownSeconds).transition(.opacity) }
            if showDailyChallengeCountdown { CountdownView(players: [], secondsRemaining: dailyChallengeCountdownSeconds).transition(.opacity) }
        }
    }
    
    private var menuButtonLayer: some View {
        VStack {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isMenuOpen.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        .padding(14).background(Color.white.opacity(0.2)).clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 20)
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    private func fetchCompletedUsers() {
        FlowLogger.trace("HomeView: Starting to fetch completed users.")
        let db = Firestore.firestore()
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let today_iso = formatter.string(from: Date())
        
        db.collection("daily_challenge_completions").document(today_iso).collection("users")
            .order(by: "completedAt", descending: true).limit(to: 10)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    FlowLogger.trace("HomeView: Error fetching completed users: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    FlowLogger.trace("HomeView: No completed user documents found.")
                    return
                }
                
                FlowLogger.trace("HomeView: Found \(documents.count) completed user documents.")
                
                let users = documents.compactMap {
                    do {
                        return try $0.data(as: CompletedUser.self)
                    } catch {
                        FlowLogger.trace("HomeView: Failed to decode user document \($0.documentID): \(error)")
                        return nil
                    }
                }
                
                FlowLogger.trace("HomeView: Successfully decoded \(users.count) users.")
                
                if self.completedUsers != users {
                    self.completedUsers = users
                    FlowLogger.trace("HomeView: Updated completedUsers state with \(users.count) users.")
                }
            }
    }
    
    private func startDailyChallenge() {
        guard !showDailyChallengeCountdown else { return }
        dailyChallengeCountdownSeconds = 3
        showDailyChallengeCountdown = true
        tickDailyChallengeCountdown()
    }

    private func tickDailyChallengeCountdown() {
        guard showDailyChallengeCountdown else { return }
        if dailyChallengeCountdownSeconds <= 0 {
            showDailyChallengeCountdown = false
            navigateToTodaysChallenge = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dailyChallengeCountdownSeconds -= 1
            tickDailyChallengeCountdown()
        }
    }
    
    private func startSkillLab() {
        guard !showStartCountdown else { return }
        countdownSeconds = 3
        showStartCountdown = true
        tickCountdown()
    }
    
    private func tickCountdown() {
        guard showStartCountdown else { return }
        if countdownSeconds <= 0 {
            showStartCountdown = false
            isStartingGame = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            countdownSeconds -= 1
            tickCountdown()
        }
    }
}

// MARK: - Helper Views & Styles

private struct PrimaryGameModeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .shadow(radius: 5, y: 3)
    }
}

struct SideMenuView: View {
    let onLeaderboard: () -> Void
    let onSettings: () -> Void
    let onMultiplayer: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Game Menu").font(.bobaland(size: 42)).foregroundColor(.white)
                SideMenuButton(icon: "trophy.fill", title: "Leaderboard", subtitle: "See who’s winning", action: onLeaderboard)
                SideMenuButton(icon: "gearshape.fill", title: "Settings", subtitle: "Adjust your settings", action: onSettings)
                SideMenuButton(icon: "person.3.fill", title: "Multiplayer", subtitle: "Play with friends", action: onMultiplayer)
                AmbientSoundMenuRow()
                Spacer()
            }
            .padding(.top, 80).padding(.bottom, 40).padding(.horizontal, 28)
            .frame(width: 280, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(red: 0.14, green: 0.12, blue: 0.26), Color(red: 0.22, green: 0.18, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .ignoresSafeArea()
            Spacer()
        }
    }
}

private struct AmbientSoundMenuRow: View {
    @AppStorage(SoundEffectPlayer.ambientLoopMutedDefaultsKey) private var isMuted = true
    var body: some View {
        HStack(spacing: 16) {
            AmbientSoundToggleButton()
            VStack(alignment: .leading, spacing: 4) {
                Text("Music").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Text(isMuted ? "Soundtrack is off" : "Soundtrack is on").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SideMenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 24, weight: .bold)).frame(width: 44, height: 44).foregroundColor(.black).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
        }
        .disabled(!isEnabled).buttonStyle(.plain)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            gameViewModel: GameViewModel(),
            showingSettings: .constant(false),
            showingLeaderboard: .constant(false),
            appState: AppState()
        )
    }
}
