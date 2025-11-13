## Multiplayer Issue Log

### 2025-11-13 — Round never advanced after a correct answer
- **Symptom:** After the first player answered correctly, the round stayed on the same equation indefinitely. The host UI showed the submitted answer and the Firestore `answers` collection updated, but no new problem appeared.
- **Root cause:** Each device always wrote to the same Firestore document (`answers/<playerId>`). Firestore’s Cloud Function trigger for `resolvemultiplayeranswer` only fires on document creation, so only the very first submission ever invoked the resolver. Subsequent questions reused the same document IDs, so no trigger → no score/round lock → no advance.
- **Fix:** Store every submission under a unique document ID that includes the question index (e.g., `<playerId>_q1`). Also record the submitting `playerId` in the document so listeners can still map answers back to the correct player. Commit: `5c5ad64` (files `Sources/TurboXTable/.../SyncService.swift`).
- **Validation:** After the change, each answer write generates a new document under `games/<code>/rounds/<roundId>/answers`, the Cloud Function fires once per question, and the host automatically advances to the next problem when `firstCorrectPlayerId` is populated.
