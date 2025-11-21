# CloudKit Notification Service Plan

Scope: deliver player-facing leaderboard change notifications using CloudKit. This builds on the existing CloudKit scaffolding in the app (`MathBlitz/TestGameStartNotifier.swift`) and the iCloud container `iCloud.MathBlitz`.

## Goals
- Player awareness: notify a player when their leaderboard position changes (improved or dropped).
- Keep CloudKit prepared: define record types, subscriptions, payload shape, and app glue needed to ship quickly after approval.

## Current State (baseline)
- App registers for pushes via OneSignal and APNs in `MathBlitz/AppDelegate.swift`.
- CloudKit entitlements are enabled for `iCloud.MathBlitz` (app + OneSignal extension).
- `TestGameStartNotifier` installs a `CKQuerySubscription` on record type `TestGameStart` in the public DB, posts a local notification on receipt, and respects a `DebugDefaults` flag. No production game/leaderboard notifications yet.

## Event Model & CloudKit Schema
- **Record: `LeaderboardStanding` (public DB)**
  - Fields: `playerId`, `playerName`, `mode`, `rank` (Int), `previousRank` (Int), `score` (Int), `season`/`boardId` (string for weekly/global separation), `updatedAt` (Date).
  - Index: queryable on `playerId`, `boardId`, `updatedAt`.

## Subscription Plan
- **Player leaderboard subscription**
  - `CKQuerySubscription` on `LeaderboardStanding` with predicate `playerId == <currentProfile.id>`.
  - Options: `.firesOnRecordUpdate`; `NotificationInfo` includes alert keys (`title/body`) plus `desiredKeys = ["rank", "previousRank", "mode", "boardId"]`.
  - Subscription ID keyed by player (`leaderboard.<playerId>`); refreshed on login/profile change.

## App-Side Work
- Create a `CloudKitNotificationManager` to replace/extend `TestGameStartNotifier`:
  - Shared container/DB accessors, install/remove subscription helpers, and a unified `handleRemoteNotification` entry that routes to handlers by `subscriptionID`.
  - Foreground handling: post `NotificationCenter` events so UI can show in-app banners; fall back to local notifications when backgrounded.
  - Debug reset hooks similar to `resetSubscriptionFlag`.
- Initialize subscriptions:
  - On launch, request notification permission (already done).
  - After profile load/auth, install the leaderboard subscription using the player’s ID; remove/replace when the user logs out or switches profiles.

## Event Emitters (backend or client writes)
- **Leaderboard change emission:**
  - When leaderboard ranks are recomputed, upsert one `LeaderboardStanding` per affected player with the new `rank`, `previousRank`, and `updatedAt`. The player’s device subscription will fire on the update.
  - Noise gate: only push for top performers; write/update records only when `rank <= 10` so notifications are limited to the top 10.
- If server access to CloudKit is delayed, a stopgap is to have clients also write the same records on important events, but production should rely on the authoritative backend to avoid missed notifications.

## Firebase Function → CloudKit (Python) template
Use in the rank recompute function (only upsert when `rank <= 10`):
```python
import os, time, uuid, requests, jwt  # pip install requests pyjwt[crypto]

TEAM_ID = os.environ["CK_TEAM_ID"]
KEY_ID = os.environ["CK_KEY_ID"]
CONTAINER = os.environ["CK_CONTAINER_ID"]      # e.g., "iCloud.MathBlitz"
CK_ENV = os.environ.get("CK_ENV", "development")
PRIVATE_KEY = os.environ["CK_PRIVATE_KEY"]     # full .p8 contents

def _cloudkit_token():
    now = int(time.time())
    return jwt.encode(
        {"iss": TEAM_ID, "iat": now, "exp": now + 45 * 60},
        PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )

def upsert_leaderboard_standing(player_id, player_name, mode, rank, prev_rank,
                                score, board_id, updated_at_iso):
    if rank > 10:
        return {"skipped": True}
    url = f"https://api.apple-cloudkit.com/database/1/{CONTAINER}/{CK_ENV}/public/records/modify"
    payload = {
        "operations": [{
            "operationType": "forceUpdate",
            "record": {
                "recordType": "LeaderboardStanding",
                "recordName": f"{board_id}-{player_id}",
                "fields": {
                    "playerId": {"value": player_id},
                    "playerName": {"value": player_name},
                    "mode": {"value": mode},
                    "rank": {"value": rank},
                    "previousRank": {"value": prev_rank},
                    "score": {"value": score},
                    "boardId": {"value": board_id},
                    "updatedAt": {"value": updated_at_iso},
                },
            },
        }]
    }
    headers = {"Authorization": f"Bearer {_cloudkit_token()}"}
    resp = requests.post(url, json=payload, headers=headers, timeout=10)
    resp.raise_for_status()
    return resp.json()
```

## CloudKit server credentials (where to get them)
- `CK_CONTAINER_ID`: iCloud container identifier (e.g., `iCloud.MathBlitz`). Found in Apple Developer → Identifiers → iCloud Containers.
- `CK_TEAM_ID`: Apple Developer team ID (upper-case letters/numbers). Visible in App Store Connect or Certificates & Identifiers page.
- `CK_KEY_ID`: Key ID of the CloudKit Web Services key. Create or reuse a Key in Apple Developer → Keys → “CloudKit Web Services.”
- `CK_PRIVATE_KEY`: The .p8 file contents for that key. Copy the full text (including `BEGIN PRIVATE KEY` / `END PRIVATE KEY`) into a secret.
- `CK_ENV`: `development` for sandbox testing; `production` once live.

## Store secrets in Firebase (gen2) / Cloud Functions
- Preferred: Google Secret Manager + secret mounts.
  - Create secrets: `gcloud secrets create CK_PRIVATE_KEY` and `gcloud secrets versions add CK_PRIVATE_KEY --data-file=AuthKey_XXXX.p8` (repeat for each).
  - Deploy the function with secret bindings:
    - `gcloud functions deploy <funcName> --runtime=python311 --region=<region> --source=. --entry-point=<handler> --trigger-event=<event> --set-secrets=CK_PRIVATE_KEY=CK_PRIVATE_KEY:latest --set-env-vars=CK_TEAM_ID=...,CK_KEY_ID=...,CK_CONTAINER_ID=iCloud.MathBlitz,CK_ENV=development`
  - For Firebase CLI (gen2), you can also use `firebase functions:secrets:set CK_PRIVATE_KEY` then bind via `--set-secrets` in `firebase functions:deploy`.
- If you must use plain env vars (less secure), pass `--set-env-vars CK_TEAM_ID=...,CK_KEY_ID=...,CK_CONTAINER_ID=...,CK_ENV=development,CK_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"`, but prefer Secret Manager for the private key.

## Notification Copy & UX
- Leaderboard: Title `"Your rank changed"`; Body `"Now #<rank> in <mode> (was #<previousRank>)"`; include mode so UI can deep-link to the correct board.
- Standardize identifiers so we can dedupe local notifications (`"leaderboard-<boardId>-<playerId>"`).

## Testing & Ops Checklist
- Use the CloudKit dev environment for test builds; switch to production container for App Store builds.
- Manual tests: create a test `LeaderboardStanding` via the CloudKit dashboard or backend; confirm `handleRemoteNotification` routes correctly.
- Load tests: ensure subscription installation succeeds after uninstall/reinstall and across app updates; store a “subscription installed” flag per-subscription ID.
- Metrics: add lightweight logging (`FlowLogger`) around subscription save/delete and notification receipt for sanity checks in TestFlight.

## Open Questions
- Which backend owns leaderboard recomputation (existing Firebase function or elsewhere), and can it call CloudKit web services?
