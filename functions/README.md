# Functions Overview

## CloudKit leaderboard push
- **Function:** `on_leaderboard_standing_change`
- **Trigger:** Firestore document write at `leaderboards/{boardId}/entries/{playerId}`
- **Behavior:** If `rank <= 10`, writes/updates `LeaderboardStanding` to CloudKit (JWT auth) to trigger the app’s CloudKit subscription.
- **Secrets:** `CK_TEAM_ID`, `CK_KEY_ID`, `CK_CONTAINER_ID`, `CK_ENV`, `CK_PRIVATE_KEY` (stored in Secret Manager; access granted to the default compute service account).
- **Firestore fields used:** `rank`, `previousRank` (optional), `playerId`, `playerName`, `mode`, `score`, `boardId` (or path param).
- **Notes:** Values must exist for `playerId` and `rank`. Dev/prod separation via `CK_ENV`.

## CloudKit test push (HTTP)
- **Function:** `send_test_leaderboard_push` (HTTP)
- **Body (JSON):** `playerId` (required), `rank` (required), `previousRank`, `playerName`, `mode`, `boardId`, `score`.
- **Behavior:** Sends a single `LeaderboardStanding` upsert to CloudKit (skips if `rank > 10`) to trigger the subscription for that player.
- **Usage:** `gcloud functions deploy send_test_leaderboard_push --entry-point=send_test_leaderboard_push --runtime=python310 --region=us-central1 --trigger-http --gen2 --set-secrets=CK_TEAM_ID=...,CK_KEY_ID=...,CK_CONTAINER_ID=...,CK_ENV=...,CK_PRIVATE_KEY=...` then call with `gcloud functions call send_test_leaderboard_push --data '{"playerId":"...", "rank":1, "previousRank":2, "mode":"kids", "boardId":"kids"}'`.

## CloudKit broadcast (HTTP)
- **Function:** `broadcast_cloudkit_message` (HTTP)
- **Body (JSON):** `message` (or `body`, required), `title` (default: "Announcement"), `data` (object, optional).
- **Behavior:** Writes a `BroadcastMessage` record to CloudKit public DB. Clients subscribed to that record type receive the notification.
- **Usage:** `firebase functions:call broadcast_cloudkit_message --data "$(cat broadcast.json)"` where `broadcast.json` contains e.g. `{"title":"Heads up","message":"Double XP weekend!","data":{"cta":"open_shop"}}`.

## Device tokens (needed for APNs broadcast)
- Store APNs tokens at `devices/{deviceId}` with: `token` (string), `bundleId`, `platform` (`ios`), `userId`, `lastSeen` (timestamp).
- The app should upsert this on launch/sign-in/sign-out so server-side fan-out (marketing/broadcast) can target devices.
