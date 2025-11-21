//
//  GameViewModel.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseAuth

#if canImport(UIKit)
import UIKit
#endif

enum BackgroundPhase {
    case countdown
    case success
    case failure
    case timeout
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var currentProblem: Problem = Problem(a: 2, b: 2)
    @Published var userAnswer: String = ""
    @Published var score: Int = 0
    @Published var isGameActive: Bool = true
    @Published var backgroundPhase: BackgroundPhase = .countdown
    @Published var timeRemainingRatio: Double = 1.0
    @Published var timeRemainingSeconds: Int = 0
    @Published var screenShake: CGFloat = 0
    @Published var currentLevelIndex: Int = 0
    @Published var questionsAnsweredInLevel: Int = 0
    @Published var remainingLives: Int = 3
    @Published var isGameOver: Bool = false
    @Published var highScore: Int = 0
    @Published var showHighScoreCelebration: Bool = false
    @Published var didBeatHighScore: Bool = false
    @Published var showSuccessFlash: Bool = false
    @Published var latestPlacement: Int?
    @Published var showPlacementToast: Bool = false
    @Published var gameMode: GameMode
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var triggerHighScoreShake = false
    
    private let maxLives = 3
    private let modeStorageKey = "MathBlitzGameMode"
    private var shouldShowPlacementToast = false
    
    var gameTimer: Timer?
    private let timerResolution: TimeInterval = 0.05
    private var roundStartTime: Date = Date()
    
    private let kidsLevels = [
        Level(levelNumber: 1, numberRange: 2...5, gameDuration: 20.0, questionsPerLevel: 5),
        Level(levelNumber: 2, numberRange: 2...8, gameDuration: 20.0, questionsPerLevel: 6),
        Level(levelNumber: 3, numberRange: 2...10, gameDuration: 20.0, questionsPerLevel: 8),
        Level(levelNumber: 4, numberRange: 4...12, gameDuration: 20.0, questionsPerLevel: 10),
        Level(levelNumber: 5, numberRange: 8...15, gameDuration: 20.0, questionsPerLevel: 12)
    ]
    
    private let adultLevels = [
        Level(levelNumber: 1, numberRange: 5...12, gameDuration: 8.0, questionsPerLevel: 6),
        Level(levelNumber: 2, numberRange: 5...15, gameDuration: 7.0, questionsPerLevel: 8),
        Level(levelNumber: 3, numberRange: 6...18, gameDuration: 6.0, questionsPerLevel: 10),
        Level(levelNumber: 4, numberRange: 8...22, gameDuration: 5.5, questionsPerLevel: 12),
        Level(levelNumber: 5, numberRange: 10...25, gameDuration: 5.0, questionsPerLevel: 14)
    ]
    
    var levels: [Level] {
        gameMode == .kids ? kidsLevels : adultLevels
    }
    
    var currentLevel: Level {
        levels[min(currentLevelIndex, levels.count - 1)]
    }
    
var totalLives: Int {
    maxLives
}

var isMultiplayerContext: Bool = false
    
    init() {
        let storedModeRaw = UserDefaults.standard.string(forKey: modeStorageKey)
        let storedMode = GameMode(rawValue: storedModeRaw ?? "") ?? .kids
        self.gameMode = storedMode
        self.highScore = UserDefaults.standard.integer(forKey: highScoreStorageKey(for: storedMode))
        FlowLogger.trace("GameViewModel initialized with mode \(storedMode.rawValue) and high score \(highScore)")
        
        if Auth.auth().currentUser != nil {
            Task { [weak self] in
                FlowLogger.trace("Initial leaderboard fetch kicked off")
                await self?.fetchLeaderboard()
            }
        } else {
            FlowLogger.trace("Skipping initial leaderboard fetch because no authenticated user is present yet")
        }
    }
    
    func updateGameMode(_ mode: GameMode) {
        guard mode != gameMode else { return }
        FlowLogger.trace("Updating game mode from \(gameMode.rawValue) to \(mode.rawValue)")
        gameMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeStorageKey)
        loadHighScore(for: mode)
        resetGame()
        Task { [weak self] in
            FlowLogger.trace("Fetching leaderboard after mode switch to \(mode.rawValue)")
            await self?.fetchLeaderboard()
        }
    }
    
    func fetchLeaderboard() async {
        do {
            FlowLogger.trace("Fetching leaderboard for mode \(gameMode.rawValue)")
            let entries = try await LeaderboardService.shared.fetchTopEntries(mode: gameMode, limit: 10)
            leaderboardEntries = entries
            FlowLogger.trace("Leaderboard fetched with \(entries.count) entries for mode \(gameMode.rawValue)")
            updatePlacement(using: entries)
            maybeTriggerPlacementToast()
        } catch {
            #if DEBUG
            print("Failed to load leaderboard: \(error.localizedDescription)")
            #endif
            FlowLogger.trace("Leaderboard fetch failed for mode \(gameMode.rawValue)")
        }
    }

    func handleNumpadPress(value: String) {
        guard isGameActive else { return }
        
        if value == "⌫" {
            if !userAnswer.isEmpty {
                userAnswer.removeLast()
            }
        } else if value == "C" {
            userAnswer = ""
        } else {
            userAnswer += value
            
            // Add a tiny delay to allow the UI to update and show the typed digit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, self.isGameActive else { return }
                
                if let answerInt = Int(self.userAnswer) {
                    if answerInt == self.currentProblem.answer {
                        self.checkAnswer(correct: true)
                    } else if self.userAnswer.count >= String(self.currentProblem.answer).count {
                        self.checkAnswer(correct: false)
                    }
                }
            }
        }
    }
    
    func newRound() {
        guard !isGameOver else { return }
        isGameActive = true
        userAnswer = ""
        backgroundPhase = .countdown
        timeRemainingRatio = 1.0
        timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        
        generateProblem()
        FlowLogger.trace("New round started → problem \(currentProblem.a) × \(currentProblem.b) (level \(currentLevel.levelNumber))")
        startCountdown()
    }
    
    func handleTimesUp() {
        guard isGameActive, backgroundPhase != .timeout else { return }
        gameTimer?.invalidate()
        isGameActive = false
        backgroundPhase = .timeout
        triggerScreenShake()
        triggerHapticFailure()
        registerMistake()
        FlowLogger.trace("Round timed out → remaining lives \(remainingLives)")
        scheduleNextRound(after: 1.2)
    }
    
    func checkAnswer(correct: Bool) {
        guard isGameActive else { return }
        gameTimer?.invalidate()
        isGameActive = false
        
        if correct {
            score += 1
            
            if score > highScore && highScore > 0 && !didBeatHighScore {
                didBeatHighScore = true
                triggerHighScoreShake = true
                triggerHapticSuccess() // Add haptic feedback here
            }
            
            questionsAnsweredInLevel += 1
            backgroundPhase = .success
            triggerHapticSuccess()
            triggerSuccessFlash()
            FlowLogger.trace("Answer correct → score \(score), questions in level \(questionsAnsweredInLevel)/\(currentLevel.questionsPerLevel)")
            
            if questionsAnsweredInLevel >= currentLevel.questionsPerLevel {
                levelUp()
            }
            
            scheduleNextRound(after: 0)
        } else {
            backgroundPhase = .failure
            triggerScreenShake()
            triggerHapticFailure()
            registerMistake()
            FlowLogger.trace("Answer incorrect → remaining lives \(remainingLives)")
            scheduleNextRound(after: 0)
        }
    }
    
    func levelUp() {
        currentLevelIndex = min(currentLevelIndex + 1, levels.count - 1)
        questionsAnsweredInLevel = 0
        FlowLogger.trace("Level up → now on level \(currentLevel.levelNumber)")
    }
    
    func resetGame() {
        gameTimer?.invalidate()
        score = 0
        currentLevelIndex = 0
        questionsAnsweredInLevel = 0
        backgroundPhase = .countdown
        timeRemainingRatio = 1.0
        remainingLives = maxLives
        isGameOver = false
        showHighScoreCelebration = false
        didBeatHighScore = false
        triggerHighScoreShake = false
        loadHighScore(for: gameMode)
        userAnswer = ""
        newRound()
        FlowLogger.trace("Game reset → mode \(gameMode.rawValue), high score \(highScore)")
        TestGameStartNotifier.shared.broadcastGameStart(mode: gameMode)
    }
    
    func prepareForManualRestart() {
        gameTimer?.invalidate()
        score = 0
        currentLevelIndex = 0
        questionsAnsweredInLevel = 0
        backgroundPhase = .countdown
        timeRemainingRatio = 1.0
        timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        remainingLives = maxLives
        showHighScoreCelebration = false
        didBeatHighScore = false
        triggerHighScoreShake = false
        userAnswer = ""
        isGameActive = false
        isGameOver = false
        FlowLogger.trace("Prepared game for manual restart → mode \(gameMode.rawValue)")
    }
    
    func quitGame() {
        gameTimer?.invalidate()
        isGameActive = false
        isGameOver = true
        FlowLogger.trace("Game quit by user")
    }
    
    func dismissCelebration() {
        showHighScoreCelebration = false
        didBeatHighScore = false
    }
    
    func triggerScreenShake() {
        let shakeAmount: CGFloat = 10
        withAnimation(.default) {
            screenShake = shakeAmount
        }
        withAnimation(.default.delay(0.1)) {
            screenShake = -shakeAmount
        }
        withAnimation(.default.delay(0.2)) {
            screenShake = shakeAmount
        }
        withAnimation(.default.delay(0.3)) {
            screenShake = 0
        }
    }
    
    private func registerMistake() {
        remainingLives = max(0, remainingLives - 1)
        if remainingLives == 0 {
            endGame()
        }
    }
    
    private func endGame() {
        gameTimer?.invalidate()
        isGameActive = false
        isGameOver = true
        if !isMultiplayerContext {
            updateHighScoreIfNeeded()
            submitScoreToLeaderboard(score)
        }
        timeRemainingSeconds = 0
        FlowLogger.trace("Game ended with score \(score)")
    }
    
    private func updateHighScoreIfNeeded() {
        guard !isMultiplayerContext else { return }
        guard score > highScore else {
            didBeatHighScore = false
            return
        }
        highScore = score
        UserDefaults.standard.set(score, forKey: highScoreStorageKey(for: gameMode))
        showHighScoreCelebration = true
        didBeatHighScore = true
        FlowLogger.trace("New high score \(score) saved for mode \(gameMode.rawValue)")
    }
    
    private func scheduleNextRound(after delay: TimeInterval) {
        if delay <= 0 {
            newRound()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.newRound()
        }
    }
    
    private func generateProblem() {
        let range = currentLevel.numberRange
        currentProblem = Problem(a: Int.random(in: range), b: Int.random(in: range))
    }
    
    private func startCountdown() {
        roundStartTime = Date()
        gameTimer?.invalidate()
        timeRemainingRatio = 1.0
        timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: timerResolution, repeats: true) { [weak self] timer in
            self?.handleTimerTick(timer: timer)
        }
    }
    
    private func handleTimerTick(timer: Timer) {
        let elapsed = Date().timeIntervalSince(roundStartTime)
        let duration = currentLevel.gameDuration
        let remaining = duration - elapsed
        
        if remaining <= 0 {
            timeRemainingRatio = 0
            timeRemainingSeconds = 0
            timer.invalidate()
            gameTimer = nil
            handleTimesUp()
            return
        }
        
        let ratio = max(0, min(1, remaining / duration))
        timeRemainingRatio = ratio
        timeRemainingSeconds = max(0, Int(ceil(remaining)))
    }
    
    private func triggerHapticSuccess() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
#endif
    }
    
    private func triggerHapticFailure() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
#endif
    }
    
    private func submitScoreToLeaderboard(_ finalScore: Int) {
        guard !isMultiplayerContext else { return }
        guard finalScore > 0 else { return }
        let mode = gameMode
        FlowLogger.trace("Submitting score \(finalScore) to leaderboard for mode \(mode.rawValue)")
        Task { [weak self] in
            do {
                try await LeaderboardService.shared.submitScore(finalScore, mode: mode)
                await self?.fetchLeaderboard()
                FlowLogger.trace("Score \(finalScore) submitted successfully for mode \(mode.rawValue)")
            } catch {
#if DEBUG
                print("Failed to submit leaderboard score: \(error.localizedDescription)")
#endif
                FlowLogger.trace("Score submission failed for mode \(mode.rawValue)")
            }
        }
    }
    
    private func loadHighScore(for mode: GameMode) {
        highScore = UserDefaults.standard.integer(forKey: highScoreStorageKey(for: mode))
    }
    
    private func highScoreStorageKey(for mode: GameMode) -> String {
        "MathBlitzHighScore_\(mode.rawValue)"
    }
    
    private func triggerSuccessFlash() {
        guard !showSuccessFlash else { return }
        showSuccessFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.showSuccessFlash = false
        }
    }
    
    private func updatePlacement(using entries: [LeaderboardEntry]) {
        guard let currentId = Auth.auth().currentUser?.uid else {
            latestPlacement = nil
            return
        }
        if let index = entries.firstIndex(where: { $0.id == currentId }) {
            latestPlacement = index + 1
        } else {
            latestPlacement = nil
        }
    }
    
    private func maybeTriggerPlacementToast() {
        guard shouldShowPlacementToast, latestPlacement != nil else { return }
        shouldShowPlacementToast = false
        showPlacementToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showPlacementToast = false
        }
    }
}
