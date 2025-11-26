import os
import time
from typing import Any, Dict, Optional

import jwt
import requests
from firebase_admin import initialize_app
from firebase_functions import firestore_fn
from firebase_functions.firestore_fn import Change, DocumentSnapshot

# Initialize Firebase Admin once per instance (safe when imported multiple times).
try:
    initialize_app()
except ValueError:
    pass


def _load_private_key() -> str:
    raw = os.environ.get("CK_PRIVATE_KEY", "")
    if "\n" in raw:
        raw = raw.replace("\n", "\n")
    if raw.startswith('"') and raw.endswith('"'):
        raw = raw[1:-1]
    return raw


TEAM_ID = os.environ.get("CK_TEAM_ID", "")
KEY_ID = os.environ.get("CK_KEY_ID", "")
CONTAINER = os.environ.get("CK_CONTAINER_ID", "")
CK_ENV = os.environ.get("CK_ENV", "development")
PRIVATE_KEY = _load_private_key()


def _cloudkit_token() -> str:
    if not all([TEAM_ID, KEY_ID, CONTAINER, PRIVATE_KEY]):
        raise RuntimeError("Missing CloudKit env vars (CK_TEAM_ID/CK_KEY_ID/CK_CONTAINER_ID/CK_PRIVATE_KEY)")
    now = int(time.time())
    return jwt.encode(
        {"iss": TEAM_ID, "iat": now, "exp": now + 45 * 60},
        PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )

def _upsert_leaderboard_standing(payload: Dict[str, Any]) -> Dict[str, Any]:
    token = _cloudkit_token()
    url = f"https://api.apple-cloudkit.com/database/1/{CONTAINER}/{CK_ENV}/public/records/modify"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.post(url, json=payload, headers=headers, timeout=10)
    resp.raise_for_status()
    return resp.json()

def _snapshot_fields(snapshot: Optional[DocumentSnapshot]) -> Dict[str, Any]:
    return snapshot.to_dict() if snapshot and snapshot.exists else {}  # type: ignore[return-value]


@firestore_fn.on_document_written(document="leaderboards/{boardId}/entries/{playerId}")
def on_leaderboard_standing_change(event: firestore_fn.Event[Change[DocumentSnapshot | None]]):
    """
    DEPRECATED: This function uses CloudKit to send leaderboard updates.
    It is replaced by direct APNs notifications.

    Trigger: Firestore document write at leaderboards/{boardId}/entries/{playerId}
    """
    after_fields = _snapshot_fields(event.data.after)
    before_fields = _snapshot_fields(event.data.before)

    player_id = after_fields.get("playerId") or event.params.get("playerId")
    rank = after_fields.get("rank")
    prev_rank = after_fields.get("previousRank") or before_fields.get("rank") or rank
    player_name = after_fields.get("playerName") or "Player"
    mode = after_fields.get("mode") or "global"
    score = after_fields.get("score") or 0
    board_id = event.params.get("boardId") or after_fields.get("boardId") or "global"
    update_time = getattr(event.data.after, "update_time", None)
    updated_at_iso = (
        update_time.isoformat().replace("+00:00", "Z") if update_time else time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    )

    if rank is None or player_id is None:
        print("CloudKit upsert skipped: missing rank or playerId")
        return

    try:
        rank_int = int(rank)
    except (TypeError, ValueError):
        print(f"CloudKit upsert skipped: invalid rank {rank}")
        return

    if rank_int > 10:
        print(f"Rank {rank_int} > 10; skipping CloudKit upsert for {player_id}")
        return

    try:
        prev_rank_val = int(prev_rank) if prev_rank is not None else rank_int
    except (TypeError, ValueError):
        prev_rank_val = rank_int

    record_name = f"{board_id}-{player_id}"

    modify_payload = {
        "operations": [
            {
                "operationType": "forceUpdate",
                "record": {
                    "recordType": "LeaderboardStanding",
                    "recordName": record_name,
                    "fields": {
                        "playerId": {"value": player_id},
                        "playerName": {"value": player_name},
                        "mode": {"value": mode},
                        "rank": {"value": rank_int},
                        "previousRank": {"value": prev_rank_val},
                        "score": {"value": int(score) if isinstance(score, (int, float)) else 0},
                        "boardId": {"value": board_id},
                        "updatedAt": {"value": updated_at_iso},
                    },
                },
            }
        ]
    }

    try:
        result = _upsert_leaderboard_standing(modify_payload)
        print(
            f"CloudKit upsert success for {record_name} rank={rank_int} prev={prev_rank_val} mode={mode}",
        )
        print(result)
    except Exception as exc:  # noqa: BLE001
        print(f"CloudKit upsert failed for {record_name}: {exc}")
        print(modify_payload)
