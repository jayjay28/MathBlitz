# TurboXTable Game Logic Guide

This guide explains, in plain language, how a single round of TurboXTable works under the hood—where questions come from, how you advance, and what the app is looking for on every tap.

## 1. Game Loop Overview
1. **Round setup (`newRound`)**
   - The game clears the prior answer, resets the timer, and grabs a new multiplication pair that fits the active level.
   - The timer bar, countdown text, and animated background all restart from full green.
2. **Counting down (`startCountdown`)**
   - Each level assigns a round duration (from 5–20 seconds).
   - A repeating timer ticks every 0.05 seconds, shrinking the progress bar and updating the seconds display.
3. **Player input (`handleNumpadPress`)**
   - Every tap appends to the answer unless you hit `C` (clear) or `⌫` (backspace).
   - As soon as the digits you typed equal the correct product—or you’ve typed as many digits as the correct answer would have—the game locks in the round.
4. **Round resolution (`checkAnswer` / `handleTimesUp`)**
   - Correct answers increment the score, add to the “questions solved in this level” counter, and briefly flash green.
   - Wrong answers or timeouts flash red, shake the screen, and cost a life.
5. **Moving on (`scheduleNextRound`)**
   - After a short celebration/penalty delay (≈0.8s for correct, 1.0–1.2s for wrong/timeout), the loop restarts with a fresh problem—unless you’ve run out of lives.

## 2. Problem Generation
- Problems are just two integers `a × b`.
- For each new round the game chooses fresh values inside the current level’s range, using Swift’s `Int.random(in: range)`.
- No history is kept, so duplicate problems are possible, but the ranges expand as you level up so repeats become rare later in a run.

## 3. Levels, Timers, and Difficulty
The game has five levels per mode. Each level controls three things: the number range for `a` and `b`, the time allowed per question, and how many correct answers you need before leveling up again.

### Kids Mode
| Level | Factors Used | Seconds per Question | Correct Answers Needed |
|-------|--------------|----------------------|------------------------|
| 1 | 2–5 | 20s | 5 |
| 2 | 2–8 | 20s | 6 |
| 3 | 2–10 | 20s | 8 |
| 4 | 4–12 | 20s | 10 |
| 5 | 8–15 | 20s | 12 |

### Adult Mode
| Level | Factors Used | Seconds per Question | Correct Answers Needed |
|-------|--------------|----------------------|------------------------|
| 1 | 5–12 | 8s | 6 |
| 2 | 5–15 | 7s | 8 |
| 3 | 6–18 | 6s | 10 |
| 4 | 8–22 | 5.5s | 12 |
| 5 | 10–25 | 5s | 14 |

- After level 5 the game keeps using the level‑5 settings, so you face the hardest numbers on every subsequent question.
- Switching between Kids and Adult modes reloads the correct level table, high score, and leaderboard before starting a fresh run.

## 4. Scoring, Lives, and Game Over
- **Score:** +1 for every correct answer. Misses don’t subtract points; they only cost time and lives.
- **Lives:** You start each run with three. Wrong answers and timeouts each burn one life. Hitting zero lives triggers `endGame`, stops the timer, and posts the score if you’re logged in.
- **High score & leaderboard:** Beating your personal high score lights a celebration and writes the new value to `UserDefaults`. When the game ends it submits the final score to the online leaderboard for the current mode.

## 5. Advancing to the Next Problem
- Correct, wrong, or timed‑out rounds all finish by calling `scheduleNextRound`, which waits a short delay so the animations and haptics can play.
- Once the delay expires, `newRound` fires again, looping back to step 1 above with a fresh randomly generated multiplication pair.

Armed with these rules you can trace any state in the UI back to a piece of logic in `GameViewModel.swift` or `Problem.swift`, and confidently explain why the game behaved the way it did on a given round.
