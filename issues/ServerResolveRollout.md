# Server-side Multiplayer Answer Resolution — Rollout Plan & Risks

## Summary
We need to move multiplayer answer resolution to the backend (Cloud Function) to eliminate client race/latency bias. The change must be rolled out safely without breaking current users.

## Current State
- All resolution is client-side:
  - Clients write answers to Firestore (`games/{gameId}/rounds/{roundId}/answers/...`).
  - `AnswerValidator.firstCorrectPlayerId` picks earliest correct by `submittedAt`.
  - Host clients advance rounds when they see `firstCorrectPlayerId`.
- No Firebase/Cloud Function exists today to arbitrate the winner.
- Numpad blocks locally when any correct answer is observed; fairness depends on client latency.

## Proposed Backend (new)
- Add `resolveMultiplayerAnswer` Cloud Function (onCreate of answer docs):
  - Validate: correct question index, correct answer.
  - Transaction: set `firstCorrectPlayerId` + `lockedAt` if not already set; increment winner score.
  - Use server timestamps; log collisions/latency.
- Clients become readers: they render `firstCorrectPlayerId` from Firestore; local resolution is a fallback only when the flag is off.

## Rollout Strategy
- Feature flag: gate server resolution (`USE_SERVER_RESOLVE`) so behavior can be toggled without an app release.
  - Option A: function env var/secret (redeploy function to flip).
  - Option B: Firestore config doc `/config/features/resolveServer` (flip via write; no redeploy).
- Steps:
  1) Deploy function with flag off → no behavior change.
  2) Ship client update that respects server-resolved winners and only self-resolves if flag is off.
  3) Enable flag in dev/staging; test internal matches; monitor logs/latency.
  4) Gradual ramp (TestFlight/small cohort) → observe collisions and lock time.
  5) Enable 100% production via flag toggle.
  6) Cleanup: remove client-side winner writes and the flag once stable.

## Risks & Mitigations
- Double winners/lock contention: transactional write guards; log collisions.
- Latency in function: measure answer-to-lock time; ensure minimal dependencies inside function.
- Config drift: document flag location; keep defaults safe (off) until verified.
- Backward compatibility: client keeps local resolution path when flag is off; blocks numpad on `firstCorrectPlayerId` regardless of setter.

## Open Items
- Decide flag source (env var vs Firestore config doc).
- Confirm Firestore answer path/fields the function will use (questionIndex, value, playerId, submittedAt). 
- Add function code and update client guards accordingly.
