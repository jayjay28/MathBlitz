import os
import time
from typing import Any, Dict

import jwt
import requests
from flask import jsonify
from firebase_admin import initialize_app
from firebase_functions import https_fn

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


@https_fn.on_request()
def send_test_leaderboard_push(request: https_fn.Request):
    """
    DEPRECATED: This function uses CloudKit to send a test leaderboard push.
    It is replaced by direct APNs notifications.

    HTTP helper to send a test leaderboard push via CloudKit.
    Body (JSON):
      {
        "playerId": "...",  # required
        "playerName": "Test Player",
        "rank": 1,
        "previousRank": 2,
        "mode": "kids",
        "boardId": "kids",
        "score": 999
      }
    """
    try:
        body = request.get_json(force=True, silent=True) or {}
    except Exception:
        body = {}

    player_id = body.get("playerId")
    player_name = body.get("playerName", "Test Player")
    rank = body.get("rank")
    prev_rank = body.get("previousRank", rank)
    mode = body.get("mode", "global")
    score = body.get("score", 0)
    board_id = body.get("boardId", "global")
    updated_at_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    if player_id is None or rank is None:
        return jsonify({"error": "playerId and rank are required"}), 400

    try:
        rank_int = int(rank)
    except (TypeError, ValueError):
        return jsonify({"error": "rank must be an integer"}), 400

    if rank_int > 10:
        return jsonify({"skipped": True, "reason": "rank > 10"}), 200

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
                        "score": {
                            "value": int(score) if isinstance(score, (int, float)) else 0
                        },
                        "boardId": {"value": board_id},
                        "updatedAt": {"value": updated_at_iso},
                    },
                },
            }
        ]
    }

    try:
        result = _upsert_leaderboard_standing(modify_payload)
        return jsonify(
            {
                "success": True,
                "recordName": record_name,
                "rank": rank_int,
                "previousRank": prev_rank_val,
                "mode": mode,
                "boardId": board_id,
                "cloudkit": result,
            }
        )
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": str(exc), "payload": modify_payload}), 500
