# TurboXTable Level System

## Overview
TurboXTable ramps up difficulty through discrete levels that tighten the allowed response window and broaden the multiplication facts. The game always starts on Level 1 and progresses upward as you clear each level’s quota of correct answers without resetting the session.

## Default Levels
| Level | Multipliers | Time Limit | Questions To Advance | Player Experience |
|-------|-------------|------------|----------------------|-------------------|
| 1 | 2 – 5 | 12 s | 5 | Gentle warm-up that only uses smaller tables. |
| 2 | 2 – 8 | 10 s | 6 | Introduces more 7s/8s while keeping everything single-digit. |
| 3 | 2 – 10 | 8 s | 8 | Adds 9s and 10s for a “ready for third grade” challenge. |
| 4 | 4 – 12 | 6 s | 10 | Carefully introduces 11s and 12s once earlier skills are solid. |
| 5 | 8 – 15 | 5 s | 12 | Double-digit “boss” level with combinations like 12×15 reserved for advanced play. |

## Progression Rules
1. **Level completion:** Each correct answer increments both the global score and the “questions answered in this level” counter. When the counter meets the level’s `questionsPerLevel`, the player levels up.
2. **Difficulty scaling:** Levels supply their own `numberRange` and `gameDuration`. The view model draws both operands from the current range and sets the countdown timer to the level’s duration, so every level simultaneously increases operand size and decreases time. Double-digit multipliers are gated to Levels 4 and 5 so younger players face them only after mastering single-digit facts.
3. **Failure handling:** Wrong answers or timeouts do not demote the player. The round simply restarts with the same level so players can try again without losing progress.
4. **Top level behavior:** After reaching the highest entry in `levels`, the game keeps using that configuration. Additional correct answers still advance the score but the level counter no longer increases.
5. **Game reset:** Calling `resetGame()` clears the score, level index, and per-level counter before starting a new Level 1 round.

## Implementation Notes
- The `Level` struct (see `TurboXTable/Level.swift`) defines the range, timer duration, and progression quota in one place. Add or reorder levels by editing the `levels` array in `GameViewModel`.
- When the level configuration changes, no UI adjustments are required—the view model automatically applies the new timing and operand ranges on the next round.
- You can tune difficulty without touching gameplay logic by manipulating the ranges, durations, and quotas to match your target audience.
