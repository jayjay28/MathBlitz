# TurboXTable Multiplayer Logic Guide

This note explains how the head-to-head mode is stitched together—what data lives in Firestore, how questions advance, and how we determine winners.

## 1. Lifecycle at a Glance
1. **Lobby (`MultiplayerPhase.lobby`)**
   - Players join the shared `games/{gameId}` document and appear in its `players` subcollection with `isReady = false`.
   - Everyone toggles ready via `toggleReady`, which simply updates their player doc.
2. **Countdown (`MultiplayerPhase.countdown`)**
   - The host calls `startMatch(mode:)` (see `Sources/Multiplayer/Services/SyncService.swift:123`), which creates the first round, seeds the first problem, and sets a three‑second countdown in the game doc.
3. **Round Loop (`MultiplayerPhase.round`)**
   - When the countdown hits zero the game doc flips to `state = "round"`.
   - All players see the shared problem from the latest `rounds/{roundId}` doc and have ~10 seconds to answer.
   - First correct answer scores and the game instantly advances to the next question.
4. **Scoreboard (`MultiplayerPhase.scoreboard`)**
   - When the host ends play (using `finishRound`) the game doc switches to `state = "scoreboard"`, locking in `winnerId`.
   - The lobby can then be reset or a new session hosted.

## 2. Firestore Data Model
| Location | Purpose |
|----------|---------|
| `games/{gameId}` | Stores session state: `state` (`lobby`, `countdown`, `round`, `scoreboard`), `countdownRemaining`, `roundStartedAt`, `winnerId`, and `gameMode`. |
| `games/{gameId}/players/{playerId}` | Mirrors each participant. Fields include `displayName`, emojitar info, `score`, `isReady`, plus optional `latestAnswer`, `isCorrect`, `isFirstCorrect`, and `submittedAt` for UI highlights (`SyncService.listenToPlayers`). |
| `games/{gameId}/rounds/{roundId}` | Holds the shared problem (`problem.a`, `problem.b`), `questionIndex`, `firstCorrectPlayerId`, `lockedAt`, and timestamps (`SyncService.makeRound`). There is typically one active round; new questions reuse the same doc. |
| `games/{gameId}/rounds/{roundId}/answers/{playerId}_q{index}` | Each submission gets its own doc via `SyncService.submit`. It records `value`, `questionIndex`, `playerId`, and `submittedAt`. Creating this doc triggers the Cloud Function described below. |

## 3. Problem & Timer Rules
- Problems use the same `Problem.random` helper as solo mode (`MathBlitz/Problem.swift:10`) but with tighter ranges:
  - Kids sessions pick factors from `2...9`.
  - Adult sessions use `5...15`.
- Every question inherits a soft 10‑second timer. `SyncService.resetQuestionTimer` arms a client-side timer whenever a new question arrives; if nobody answers in time, the host’s device calls `skipToNextQuestion` to generate a fresh problem.

## 4. Answer Resolution Flow
1. **Submitting:** When a player hits Enter, the client calls `SyncService.submit`, which writes the answer document for the current `questionIndex`.
2. **Server validation:** The `resolveMultiplayerAnswer` Cloud Function (`functions/main.py:12`) runs for every new answer doc. Inside a Firestore transaction it:
   - Exits if a winner already exists for the round or if the submission’s `questionIndex` doesn’t match the current one.
   - Checks the product (`problem.a * problem.b`) and, if correct, stores `firstCorrectPlayerId` and `lockedAt` on the round while incrementing the player’s `score`.
3. **Client updates:** All devices listen to the answers collection (`SyncService.listenToAnswers`). The helper `AnswerValidator.annotatePlayers` flags whose answer was first, fills `latestAnswer`, and updates the HUD so spectators instantly see who solved it.

## 5. Advancing Questions
- **Host-driven advance:** The local host (set via `setIsLocalHost(true)`) watches for `firstCorrectPlayerId`. When it changes, `advanceToNextQuestion` fires after a short delay to let celebrations play.
- **What it does:** The method reuses the existing round doc, increments `questionIndex`, picks a new random problem (mode-dependent range), clears `firstCorrectPlayerId/lockedAt`, timestamps `startedAt`, and deletes the old `answers` subcollection so stale documents don’t leak into the next question.
- **Timeout fallback:** If no one solved the problem before the 10-second timer, `skipToNextQuestion` runs the same update path but skips the celebration delay.

## 6. Ending and Resetting
- `finishRound` stops the per-question timer and flips the game into `scoreboard` state with a `winnerId` chosen by `determineWinnerId` (highest score, alphabetical tiebreaker).
- `resetGameDocument` wipes players, rounds, and answers before setting the lobby defaults for a fresh session; `deleteCurrentGame` removes the session entirely if the host quits.

## 7. Putting It Together
- **From a player’s perspective:** join the lobby, ready up, race to be the first correct solver for each multiplication problem, and rack up points before the host ends the match.
- **Under the hood:** Firestore acts as the source of truth for the game phase, shared problem, and answer stream, the Cloud Function ensures exactly one winner per question, and the host device shepherds question-to-question flow so every player stays synchronized.
