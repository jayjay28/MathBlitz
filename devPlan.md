# 🚗 Turbo Times Table Development Plan (iOS / SwiftUI)

**Project Name:** Turbo Times Table  
**Platform:** iOS / SwiftUI  
**Core Goal:** Create a time-pressured multiplication quiz with a **5-second limit** and a **racing visual**. Uses SwiftUI state management, timers, and simple animation.

---

## Phase 1 — Core State, Data, and Timing (The 5-Second Pressure)

This phase builds the foundation: logic, state, and the time constraint.

| Component | Swift/SwiftUI Detail | Purpose |
|---------|----------------------|---------|
| **Data Model** | `struct Problem { let a: Int; let b: Int; var answer: Int }` | Stores two multiplicands and the correct solution. |
| **Game State** | `@State private var currentProblem: Problem`<br>`@State private var userAnswer: String`<br>`@State private var score: Int` | Tracks current question, player input, and score. |
| **Timer** | `let gameDuration: TimeInterval = 5.0`<br>`@State private var gameTimer: Timer?` | Controls the **5 second limit**. |
| **Activity Flag** | `@State private var isGameActive: Bool` | Disables input & timer checks during feedback scenes. |
| **Numpad Logic** | `func handleNumpadPress(value: String)` | Appends digits, handles backspace/clear, updates input. |

---

## Phase 2 — User Interface & Visuals

This phase focuses on layout and the racing metaphor.

| Component | SwiftUI Implementation Detail | Goal |
|---------|-------------------------------|------|
| **Root Layout** | `GeometryReader` → full-screen `VStack` on a deep blue background | Scales cleanly across iPad & iPhone. |
| **Question Display** | Large, heavy **Text** for `6 × 7 = ?` and **bold colored** `userAnswer` (e.g., cyan). | Must be readable at a glance and under pressure. |
| **Numpad** | `numpadView`: nested `VStack` + `HStack`, large circular buttons. | Fast tapping ≈ fast thinking. |
| **The Track** | `ZStack`: Dark gray `RoundedRectangle` + finish line (`flag.checkered.2.crossed`). | Represents countdown visually. |
| **The Car** | `Image(systemName: "cube.fill")` tinted bright red. | Moves across track to show remaining time. |

---

## Phase 3 — Turbo Animation & Game Flow

This phase coordinates the timer, animation, scoring, and transitions.

| Logic Step | Implementation Action | Timing & Effect |
|-----------|----------------------|----------------|
| **Start Round** | `newRound()` generates new `Problem`, clears input, resets timer, sets `isGameActive = true`. | Resets player state cleanly. |
| **Start Animation** | `withAnimation(.linear(duration: gameDuration)) { carPosition = 1.0 }` | Car moves from start to finish over **exactly 5 seconds**. |
| **Correct Answer (Win)** | `checkAnswer()` stops timer & animation, increases score, shows success feedback. Then calls `newRound()` after ~1.5s. | Smooth victory flow. |
| **Time Loss** | `handleTimesUp()` triggers when timer expires, shows "Time’s Up!", then calls `newRound()` after ~2.0s. | Emphasizes urgency. |
| **Wrong Answer (Loss)** | `checkAnswer()` stops timer, forces `carPosition = 1.0` instantly (crash), shows "Wrong!", then calls `newRound()` after ~2.0s. | Creates emotional stakes. |

---

### Optional Future Enhancements
- Sound effects (car zoom, crash, cheering)
- Difficulty scaling: faster timer or larger numbers
- Animated character (Numberblocks-style cube)
- Multiplayer race mode (local Wi-Fi or Game Center)
- Cloud leaderboard + player profiles

---

## Phase 4 — Leaderboard & Dual-Lane Progression (Firebase-backed)

| Track | Implementation Notes | Questions / Dependencies |
|-------|----------------------|--------------------------|
| **Shared Foundation** | Introduce Firebase (Firestore or Realtime DB) to store high scores, player tags, and mode metadata. Use anonymous auth by default, optional sign-in later. | Need Firebase project ID, `GoogleService-Info.plist`, and which Firebase products are approved (Auth? Analytics?). |
| **Kids Path** | Keep gentle pacing, cap operands ≤ 12, and surface a “Buddy Board” leaderboard limited to kid-tagged profiles. UI: bold glyphs, larger tap targets, optional guardian gate for settings. | Confirm COPPA/parental consent requirements; need copy for kid profile creation. |
| **Adults Path** | Unlock tougher tables (up to 25), faster timers, and a global leaderboard. Provide streak multipliers, weekly reset, and option to filter by age group. | Decide if adult users must authenticate (Sign in with Apple?) before posting scores. |
| **Mode Selection** | Add a launch screen toggle or profile picker to choose “Kid Turbo” vs “Adult Turbo.” Remember selection with `AppStorage`. | Need illustrations/naming for both modes. |
| **Leaderboard UI** | SwiftUI list showing top 20 + player’s rank. Highlight personal best and previous run. Integrate celebratory view when a score enters top X. | Need decision on avatar style (initials? emoji?) and color palette alignment. |

Next steps once Firebase config is supplied:
1. Install Firebase SDK via Swift Package Manager.
2. Wire up anonymous auth + submit scores after each run.
3. Build dual-mode toggles and conditionally load data from `/leaderboards/kids` vs `/leaderboards/adults`.

Let me know when you have the Firebase credentials (or if you want me to scaffold the plist and SPM dependency now). Anything else you want defined for the two tracks?

