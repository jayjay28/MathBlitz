//
//  SyncService.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class MultiplayerSyncService: ObservableObject {
    static let shared = MultiplayerSyncService()
    private let maxPlayers = 3
    
    @Published private(set) var game: MultiplayerGame = .placeholder
    var capacity: Int { maxPlayers }
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var answersListener: ListenerRegistration?
    private var questionTimer: Timer?
    private var pendingRegistrations: Set<String> = []
    private var currentGameId: String?
    private var currentMode: GameMode = .kids
    private var roundsCache: [String: MultiplayerRound] = [:]
    private var processedAnswerKeys: Set<String> = []
    private var currentQuestionIndex: Int = 1
    private var isLocalHost = false
    private var isPreviewMode = false
    
    private init() {}
    
#if DEBUG
    func configurePreview(game: MultiplayerGame) {
        isPreviewMode = true
        self.game = game
        FlowLogger.trace("Multiplayer preview configured → phase \(game.phase)")
    }
#endif
    
    func setIsLocalHost(_ flag: Bool) {
        isLocalHost = flag
        FlowLogger.trace("Multiplayer host role updated → \(flag)")
    }
    
    func attach(gameId: String) {
        guard !isPreviewMode else {
            FlowLogger.trace("Multiplayer attach skipped → preview mode")
            return
        }
        guard currentGameId != gameId else { return }
        detachListeners()
        currentGameId = gameId
        FlowLogger.trace("Multiplayer attach → gameId \(gameId)")
        game.id = gameId
        listenToGameDocument(gameId: gameId)
        listenToPlayers(gameId: gameId)
        listenToCurrentRound(gameId: gameId)
    }
    
    func detach() {
        guard !isPreviewMode else { return }
        detachListeners()
        currentGameId = nil
        game = .placeholder
    }
    
    func registerPlayerIfNeeded(profile: PlayerProfile) async {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId else {
            FlowLogger.trace("Multiplayer register skipped → missing gameId")
            return
        }
        if game.players.contains(where: { $0.id == profile.id }) {
            FlowLogger.trace("Multiplayer register skipped → already present")
            return
        }
        if pendingRegistrations.contains(profile.id) {
            FlowLogger.trace("Multiplayer register skipped → already pending")
            return
        }
        if game.players.count >= maxPlayers {
            FlowLogger.trace("Multiplayer register skipped → lobby full (\(game.players.count)/\(maxPlayers))")
            return
        }
        pendingRegistrations.insert(profile.id)
        defer { pendingRegistrations.remove(profile.id) }
        let payload: [String: Any] = [
            "playerId": profile.id,
            "displayName": profile.displayName,
            "emoji": profile.emojitar.emoji,
            "colorHex": profile.emojitar.colorHex,
            "score": 0,
            "isReady": false,
            "preferredMode": profile.preferredMode.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            FlowLogger.trace("Multiplayer register start → \(profile.displayName)")
            try await db.collection("games")
                .document(gameId)
                .collection("players")
                .document(profile.id)
                .setData(payload, merge: true)
            FlowLogger.trace("Multiplayer register success → \(profile.displayName)")
        } catch {
            FlowLogger.trace("Multiplayer register failed → \(error.localizedDescription)")
        }
    }
    
    func toggleReady(isReady: Bool, profile: PlayerProfile) async {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId else { return }
        do {
            FlowLogger.trace("Multiplayer ready toggle start → \(profile.displayName) ready=\(isReady)")
            let currentScore = game.players.first(where: { $0.id == profile.id })?.score ?? 0
            let payload: [String: Any] = [
                "playerId": profile.id,
                "displayName": profile.displayName,
                "emoji": profile.emojitar.emoji,
                "colorHex": profile.emojitar.colorHex,
                "score": currentScore,  
                "isReady": isReady,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            try await db.collection("games")
                .document(gameId)
                .collection("players")
                .document(profile.id)
                .setData(payload, merge: true)
            FlowLogger.trace("Multiplayer ready toggle success → \(profile.displayName)")
        } catch {
            FlowLogger.trace("Multiplayer ready toggle failed → \(error.localizedDescription)")
        }
    }
    
    func startMatch(mode: GameMode) async {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId else {
            FlowLogger.trace("Multiplayer start match skipped → missing gameId")
            return
        }
        guard game.players.count >= 2 else {
            FlowLogger.trace("Multiplayer start match skipped → need at least 2 players")
            return
        }
        guard game.players.count <= maxPlayers else {
            FlowLogger.trace("Multiplayer start match skipped → lobby over capacity")
            return
        }
        let problemRange: ClosedRange<Int> = mode == .kids ? 2...9 : 5...15
        let problem = Problem.random(range: problemRange)
        let roundId = UUID().uuidString.lowercased()
        let gameRef = db.collection("games").document(gameId)
        let roundRef = gameRef.collection("rounds").document(roundId)
        let countdownSeconds = 3
        currentMode = mode
        
        await resetScoresForNewMatch(gameId: gameId)
        
        do {
            FlowLogger.trace("Multiplayer start match → countdown + round \(roundId)")
            try await gameRef.setData([
                "state": "countdown",
                "countdownRemaining": countdownSeconds,
                "winnerId": FieldValue.delete(),
                "roundStartedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            try await roundRef.setData([
                "problem": ["a": problem.a, "b": problem.b],
                "state": MultiplayerRoundState.open.rawValue,
                "startedAt": FieldValue.serverTimestamp(),
                "questionIndex": 1,
                "firstCorrectPlayerId": FieldValue.delete()
            ], merge: true)
            FlowLogger.trace("Multiplayer round created → \(roundId)")
            
            for remaining in stride(from: countdownSeconds - 1, through: 0, by: -1) {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await gameRef.setData([
                    "countdownRemaining": remaining
                ], merge: true)
            }
            
            try await gameRef.setData([
                "state": "round",
                "countdownRemaining": 0,
                "roundStartedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            FlowLogger.trace("Multiplayer countdown completed → round live")
        } catch {
            FlowLogger.trace("Multiplayer start match failed → \(error.localizedDescription)")
        }
    }
    
    private func resetScoresForNewMatch(gameId: String) async {
        do {
            let playersSnapshot = try await db.collection("games")
                .document(gameId)
                .collection("players")
                .getDocuments()
            for playerDoc in playersSnapshot.documents {
                try await playerDoc.reference.updateData([
                    "score": 0,
                    "isReady": false,
                    "latestAnswer": FieldValue.delete(),
                    "isCorrect": FieldValue.delete(),
                    "isFirstCorrect": FieldValue.delete(),
                    "submittedAt": FieldValue.delete()
                ])
            }
            FlowLogger.trace("Multiplayer scores reset for new match")
        } catch {
            FlowLogger.trace("Failed to reset scores for rematch → \(error.localizedDescription)")
        }
    }
    
    func submit(answer: Int, for profile: PlayerProfile, roundId: String) async throws {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId,
              let questionIndex = game.currentRound?.questionIndex else { return }
        FlowLogger.trace("Submit answer \(answer) q\(questionIndex) by \(profile.displayName)")
        let answersRef = db.collection("games")
            .document(gameId)
            .collection("rounds")
            .document(roundId)
            .collection("answers")
        
        let payload: [String: Any] = [
            "value": answer,
            "submittedAt": FieldValue.serverTimestamp(),
            "playerId": profile.id,
            "questionIndex": questionIndex
        ]
        
        let documentId = "\(profile.id)_q\(questionIndex)"
        
        do {
            try await answersRef.document(documentId).setData(payload, merge: false)
            FlowLogger.trace("Answer stored for \(profile.displayName) value=\(answer) q\(questionIndex)")
        } catch {
            FlowLogger.trace("Answer submit failed → \(error.localizedDescription)")
        }
    }
    
    func finishRound() async {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId else { return }
        questionTimer?.invalidate()
        let winnerId = determineWinnerId()
        let gameRef = db.collection("games").document(gameId)
        var payload: [String: Any] = [
            "state": "scoreboard",
            "roundStartedAt": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let winnerId {
            payload["winnerId"] = winnerId
        } else {
            payload["winnerId"] = FieldValue.delete()
        }
        do {
            try await gameRef.setData(payload, merge: true)
            FlowLogger.trace("Multiplayer round finished → winner \(winnerId ?? "none")")
            await resetReadyFlagsForRematch()
        } catch {
            FlowLogger.trace("Multiplayer finish round failed → \(error.localizedDescription)")
        }
    }
    
    func returnToLobby() async {
        guard isLocalHost else {
            FlowLogger.trace("Return to lobby ignored → not host")
            return
        }
        guard let gameId = currentGameId else {
            FlowLogger.trace("Return to lobby ignored → missing gameId")
            return
        }
        
        let gameRef = db.collection("games").document(gameId)
        do {
            let playersSnapshot = try await gameRef.collection("players").getDocuments()
            for playerDoc in playersSnapshot.documents {
                try await playerDoc.reference.updateData([
                    "isReady": false,
                    "score": 0,
                    "latestAnswer": FieldValue.delete(),
                    "isCorrect": FieldValue.delete(),
                    "isFirstCorrect": FieldValue.delete(),
                    "submittedAt": FieldValue.delete()
                ])
            }
            
            try await gameRef.setData([
                "state": "lobby",
                "countdownRemaining": 0,
                "roundStartedAt": FieldValue.delete(),
                "winnerId": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            processedAnswerKeys.removeAll()
            currentQuestionIndex = 1
            questionTimer?.invalidate()
            FlowLogger.trace("Multiplayer returned to lobby → \(gameId)")
        } catch {
            FlowLogger.trace("Return to lobby failed → \(error.localizedDescription)")
        }
    }
    
    func resetGameDocument(gameId: String, mode: GameMode) async {
        guard !isPreviewMode else { return }
        let gameRef = db.collection("games").document(gameId)
        do {
            let playersSnapshot = try await gameRef.collection("players").getDocuments()
            for doc in playersSnapshot.documents {
                try await doc.reference.delete()
            }
            let roundsSnapshot = try await gameRef.collection("rounds").getDocuments()
            for roundDoc in roundsSnapshot.documents {
                let answers = try await roundDoc.reference.collection("answers").getDocuments()
                for ans in answers.documents {
                    try await ans.reference.delete()
                }
                try await roundDoc.reference.delete()
            }
            try await gameRef.setData([
                "state": "lobby",
                "countdownRemaining": 0,
                "winnerId": FieldValue.delete(),
                "gameMode": mode.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            currentMode = mode
            processedAnswerKeys.removeAll()
            currentQuestionIndex = 1
            FlowLogger.trace("Multiplayer session reset → \(gameId)")
        } catch {
            FlowLogger.trace("Multiplayer session reset failed → \(error.localizedDescription)")
        }
    }
    
    func deleteCurrentGame() async {
        guard !isPreviewMode else { return }
        guard let gameId = currentGameId else { return }
        await deleteGameDocument(gameId: gameId)
    }
    
    private func deleteGameDocument(gameId: String) async {
        guard !isPreviewMode else { return }
        let gameRef = db.collection("games").document(gameId)
        do {
            FlowLogger.trace("Deleting game document → \(gameId)")
            let roundsSnapshot = try await gameRef.collection("rounds").getDocuments()
            for roundDoc in roundsSnapshot.documents {
                let answers = try await roundDoc.reference.collection("answers").getDocuments()
                for answer in answers.documents {
                    try await answer.reference.delete()
                }
                try await roundDoc.reference.delete()
            }
            let playersSnapshot = try await gameRef.collection("players").getDocuments()
            for playerDoc in playersSnapshot.documents {
                try await playerDoc.reference.delete()
            }
            try await gameRef.delete()
            FlowLogger.trace("Game document deleted → \(gameId)")
        } catch {
            FlowLogger.trace("Game deletion failed → \(error.localizedDescription)")
        }
    }
    
    private func resetReadyFlagsForRematch() async {
        guard let gameId = currentGameId else { return }
        do {
            let playersSnapshot = try await db.collection("games")
                .document(gameId)
                .collection("players")
                .getDocuments()
            for doc in playersSnapshot.documents {
                try await doc.reference.updateData([
                    "isReady": false
                ])
            }
            FlowLogger.trace("Player ready flags cleared for rematch selection")
        } catch {
            FlowLogger.trace("Failed to clear ready flags → \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private listeners
    
    private func listenToGameDocument(gameId: String) {
        let listener = db.collection("games")
            .document(gameId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Multiplayer game snapshot error → \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                self.game.phase = self.phase(from: data)
                if let timestamp = data["updatedAt"] as? Timestamp {
                    self.game.updatedAt = timestamp.dateValue()
                } else {
                    self.game.updatedAt = Date()
                }
                self.game.winnerId = data["winnerId"] as? String
            }
        listeners.append(listener)
    }
    
    private func listenToPlayers(gameId: String) {
        let listener = db.collection("games")
            .document(gameId)
            .collection("players")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Multiplayer players snapshot error → \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                FlowLogger.trace("Multiplayer players snapshot → \(snapshot.documents.count) docs")
                let players = snapshot.documents.compactMap { doc -> MultiplayerPlayerState? in
                    let data = doc.data()
                    guard
                        let displayName = data["displayName"] as? String,
                        let emoji = data["emoji"] as? String,
                        let colorHex = data["colorHex"] as? String
                    else {
                        return nil
                    }
                    let score = data["score"] as? Int ?? 0
                    let isReady = data["isReady"] as? Bool ?? false
                    let answerValue = data["latestAnswer"] as? Int
                    let isCorrect = data["isCorrect"] as? Bool ?? false
                    let isFirst = data["isFirstCorrect"] as? Bool ?? false
                    let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
                    let preferredModeRaw = data["preferredMode"] as? String ?? GameMode.kids.rawValue
                    let preferredMode = GameMode(rawValue: preferredModeRaw) ?? .kids
                    var profile = PlayerProfile.fresh(
                        id: doc.documentID,
                        displayName: displayName,
                        emojitar: Emojitar(emoji: emoji, colorHex: colorHex),
                        mode: preferredMode
                    )
                    profile.preferredMode = preferredMode
                    return MultiplayerPlayerState(
                        profile: profile,
                        isReady: isReady,
                        score: score,
                        latestAnswer: answerValue,
                        isCorrect: isCorrect,
                        isFirstCorrect: isFirst,
                        submittedAt: submittedAt
                    )
                }
                self.game.players = players
                FlowLogger.trace("Multiplayer players parsed → \(players.count) players")
            }
        listeners.append(listener)
    }
    
    private func listenToCurrentRound(gameId: String) {
        let listener = db.collection("games")
            .document(gameId)
            .collection("rounds")
            .order(by: "startedAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Multiplayer round snapshot error → \(error.localizedDescription)")
                    return
                }
                guard let latest = snapshot?.documents.first else {
                    self.game.currentRound = nil
                    self.roundsCache.removeAll()
                    self.processedAnswerKeys.removeAll()
                    FlowLogger.trace("Multiplayer round snapshot → none")
                    return
                }
                
                let round = self.makeRound(from: latest.data(), id: latest.documentID)
                if round.questionIndex != self.currentQuestionIndex {
                    FlowLogger.trace("Round snapshot question advanced \(self.currentQuestionIndex) → \(round.questionIndex)")
                    self.processedAnswerKeys.removeAll()
                    self.currentQuestionIndex = round.questionIndex
                }
                self.game.currentRound = round
                self.roundsCache[round.id] = round
                FlowLogger.trace("Multiplayer round snapshot → \(round.id) state \(round.state.rawValue)")
                self.listenToAnswers(gameId: gameId, roundId: latest.documentID)
                self.resetQuestionTimer()
                
                if self.isLocalHost,
                   let winnerId = round.firstCorrectPlayerId,
                   !winnerId.isEmpty {
                    let key = "\(round.id)#\(round.questionIndex)"
                    if !self.processedAnswerKeys.contains(key) {
                        self.processedAnswerKeys.insert(key)
                        Task {
                            await self.advanceToNextQuestion(roundId: round.id,
                                                             currentQuestionIndex: round.questionIndex)
                        }
                    }
                }
            }
        listeners.append(listener)
    }
    
    private func listenToAnswers(gameId: String, roundId: String) {
        answersListener?.remove()
        answersListener = db.collection("games")
            .document(gameId)
            .collection("rounds")
            .document(roundId)
            .collection("answers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Multiplayer answers snapshot error → \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                guard var currentRound = self.roundsCache[roundId] ?? self.game.currentRound else {
                    FlowLogger.trace("Answers snapshot skipped → missing round cache for \(roundId)")
                    return
                }
                
                let activeQuestionIndex = currentRound.questionIndex
                FlowLogger.trace("Multiplayer answers snapshot → \(snapshot.documents.count) docs for round \(roundId) (q\(activeQuestionIndex))")
                
                let answers = snapshot.documents.compactMap { doc -> MultiplayerRound.AnswerSubmission? in
                    let data = doc.data()
                    guard
                        let value = data["value"] as? Int,
                        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
                    else { return nil }
                    let answerQuestionIndex = data["questionIndex"] as? Int ?? activeQuestionIndex
                    guard answerQuestionIndex == activeQuestionIndex else { return nil }
                    let isCorrect: Bool
                    if let problem = currentRound.problem as Problem? {
                        isCorrect = value == problem.answer
                    } else {
                        isCorrect = data["isCorrect"] as? Bool ?? false
                    }
                    FlowLogger.trace("Answer read → player=\(doc.documentID) value=\(value) correct=\(isCorrect) q=\(answerQuestionIndex)")
                    let playerId = data["playerId"] as? String ?? doc.documentID
                    return MultiplayerRound.AnswerSubmission(
                        id: doc.documentID,
                        playerId: playerId,
                        value: value,
                        isCorrect: isCorrect,
                        submittedAt: submittedAt
                    )
                }
                currentRound.answers = answers
                let annotated = AnswerValidator.annotatePlayers(players: self.game.players, round: currentRound)
                self.game.players = annotated
                self.game.currentRound = currentRound
                self.roundsCache[roundId] = currentRound
            }
    }
    
    private func makeRound(from data: [String: Any], id: String) -> MultiplayerRound {
        let problemData = data["problem"] as? [String: Int] ?? [:]
        let problem = Problem(
            a: problemData["a"] ?? 0,
            b: problemData["b"] ?? 0
        )
        let stateRaw = data["state"] as? String ?? MultiplayerRoundState.open.rawValue
        let state = MultiplayerRoundState(rawValue: stateRaw) ?? .open
        let startedAt = (data["startedAt"] as? Timestamp)?.dateValue() ?? Date()
        let lockedAt = (data["lockedAt"] as? Timestamp)?.dateValue()
        let firstCorrect = data["firstCorrectPlayerId"] as? String
        let questionIndex = data["questionIndex"] as? Int ?? 1
        
        return MultiplayerRound(
            id: id,
            problem: problem,
            state: state,
            startedAt: startedAt,
            lockedAt: lockedAt,
            answers: [],
            firstCorrectPlayerId: firstCorrect,
            questionIndex: questionIndex
        )
    }
    
    private func phase(from data: [String: Any]) -> MultiplayerPhase {
        let state = data["state"] as? String ?? "lobby"
        if let modeRaw = data["gameMode"] as? String,
           let mode = GameMode(rawValue: modeRaw) {
            currentMode = mode
        }
        switch state {
        case "countdown":
            let remaining = data["countdownRemaining"] as? Double ?? 0
            self.game.roundStartedAt = nil
            return .countdown(remaining: remaining)
        case "round":
            if let ts = data["roundStartedAt"] as? Timestamp {
                self.game.roundStartedAt = ts.dateValue()
            }
            return .round
        case "scoreboard":
            self.game.roundStartedAt = nil
            return .scoreboard
        default:
            self.game.roundStartedAt = nil
            return .lobby
        }
    }
    
    private func detachListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        answersListener?.remove()
        answersListener = nil
        questionTimer?.invalidate()
    }
    
    private func determineWinnerId() -> String? {
        let sorted = game.players.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.profile.displayName < rhs.profile.displayName
            }
            return lhs.score > rhs.score
        }
        guard let top = sorted.first, top.score > 0 else { return nil }
        return top.id
    }
    
    private func advanceToNextQuestion(roundId: String, currentQuestionIndex: Int) async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        guard let gameId = currentGameId else { return }
        let roundRef = db.collection("games")
            .document(gameId)
            .collection("rounds")
            .document(roundId)

        do {
            try await db.runTransaction { transaction, errorPointer -> Any? in
                let roundSnapshot: DocumentSnapshot
                do {
                    try roundSnapshot = transaction.getDocument(roundRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                guard let data = roundSnapshot.data(),
                      let storedIndex = data["questionIndex"] as? Int,
                      storedIndex == currentQuestionIndex else {
                    FlowLogger.trace("Advance question aborted → index mismatch")
                    return nil
                }

                let nextIndex = currentQuestionIndex + 1
                let mode = self.currentMode
                let nextProblemRange: ClosedRange<Int> = mode == .kids ? 2...9 : 5...15
                let nextProblem = Problem.random(range: nextProblemRange)
                
                transaction.updateData([
                    "questionIndex": nextIndex,
                    "problem": ["a": nextProblem.a, "b": nextProblem.b],
                    "startedAt": FieldValue.serverTimestamp(),
                    "firstCorrectPlayerId": FieldValue.delete(),
                    "lockedAt": FieldValue.delete()
                ], forDocument: roundRef)
                
                return nil
            }
            FlowLogger.trace("Advanced to question \(currentQuestionIndex + 1)")
            await clearAnswers(for: roundRef)
        } catch {
            FlowLogger.trace("Advance question transaction failed → \(error.localizedDescription)")
        }
    }
    
    private func clearAnswers(for roundRef: DocumentReference) async {
        do {
            let answersSnapshot = try await roundRef.collection("answers").getDocuments()
            FlowLogger.trace("Clearing \(answersSnapshot.documents.count) answers for round \(roundRef.documentID)")
            for doc in answersSnapshot.documents {
                try await doc.reference.delete()
            }
        } catch {
            FlowLogger.trace("Answer cleanup failed → \(error.localizedDescription)")
        }
    }
    
    private func resetQuestionTimer() {
        questionTimer?.invalidate()
        guard game.phase == .round else { return }
        guard isLocalHost else {
            FlowLogger.trace("Question timer skipped → not host")
            return
        }
        
        questionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            FlowLogger.trace("Question timer fired")
            Task {
                await self.skipToNextQuestion()
            }
        }
    }

    private func skipToNextQuestion() async {
        guard isLocalHost else {
            FlowLogger.trace("Skip question ignored → not host")
            return
        }
        guard let gameId = currentGameId,
              let round = game.currentRound else { return }
        
        let roundRef = db.collection("games")
            .document(gameId)
            .collection("rounds")
            .document(round.id)
        
        var advanced = false
        do {
            try await db.runTransaction { transaction, errorPointer -> Any? in
                let roundSnapshot: DocumentSnapshot
                do {
                    try roundSnapshot = transaction.getDocument(roundRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                
                if let existingWinner = roundSnapshot.data()?["firstCorrectPlayerId"] as? String, !existingWinner.isEmpty {
                    FlowLogger.trace("Skip question aborted → winner already exists: \(existingWinner)")
                    return nil
                }
                
                let currentQuestionIndex = roundSnapshot.data()?["questionIndex"] as? Int ?? 1
                let nextIndex = currentQuestionIndex + 1
                let mode = self.currentMode
                let nextProblemRange: ClosedRange<Int> = mode == .kids ? 2...9 : 5...15
                let nextProblem = Problem.random(range: nextProblemRange)
                
                transaction.updateData([
                    "questionIndex": nextIndex,
                    "problem": ["a": nextProblem.a, "b": nextProblem.b],
                    "startedAt": FieldValue.serverTimestamp(),
                    "firstCorrectPlayerId": FieldValue.delete()
                ], forDocument: roundRef)
                
                advanced = true
                return nil
            }
            if advanced {
                FlowLogger.trace("Question skipped via timeout to question \(round.questionIndex + 1)")
                await clearAnswers(for: roundRef)
            }
        } catch {
            FlowLogger.trace("Skip question transaction failed → \(error.localizedDescription)")
        }
    }
}
