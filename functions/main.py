import asyncio
import json
import os
import time
from typing import Any, Dict, Optional

import jwt
import requests
from flask import jsonify
from firebase_admin import initialize_app, firestore
from firebase_functions import firestore_fn, https_fn
from firebase_functions.firestore_fn import Change, DocumentSnapshot

from apns_sender import APNsSender

# Initialize Firebase Admin once per instance (safe when imported multiple times).
try:
    initialize_app()
except ValueError:
    pass

# Initialize APNsSender
try:
    apns_sender = APNsSender()
except ValueError as e:
    print(f"Failed to initialize APNsSender: {e}")
    apns_sender = None


def _load_private_key() -> str:
    raw = os.environ.get("CK_PRIVATE_KEY", "")
    if "\\n" in raw:
        raw = raw.replace("\\n", "\n")
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


def _broadcast_cloudkit_message(title: str, body: str, data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    record_name = f"broadcast-{int(time.time())}"
    fields: Dict[str, Any] = {
        "title": {"value": title},
        "body": {"value": body},
        "createdAt": {"value": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
    }
    if data:
        fields["data"] = {"value": json.dumps(data)}

    payload = {
        "operations": [
            {
                "operationType": "forceUpdate",
                "record": {
                    "recordType": "BroadcastMessage",
                    "recordName": record_name,
                    "fields": fields,
                },
            }
        ]
    }
    return _upsert_leaderboard_standing(payload)


@https_fn.on_request()
def broadcast_cloudkit_message(request: https_fn.Request):
    """
    DEPRECATED: This function uses CloudKit to broadcast messages.
    It is replaced by direct APNs notifications.

    Broadcast to all CloudKit subscribers by writing a BroadcastMessage record.
    Body (JSON): {"title": "...", "message": "...", "data": {...}}
    """
    try:
        body = request.get_json(force=True, silent=True) or {}
    except Exception:
        body = {}

    message = body.get("message") or body.get("body")
    title = body.get("title", "Announcement")
    data = body.get("data") if isinstance(body.get("data"), dict) else None

    if not message:
        return jsonify({"error": "message/body is required"}), 400

    loaded_env = {
        "CK_TEAM_ID": bool(TEAM_ID),
        "CK_KEY_ID": bool(KEY_ID),
        "CK_CONTAINER_ID": bool(CONTAINER),
        "CK_PRIVATE_KEY": bool(PRIVATE_KEY),
    }

    try:
        result = _broadcast_cloudkit_message(title=title, body=message, data=data)
        return jsonify({"success": True, "cloudkit": result, "env": loaded_env}), 200
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": str(exc), "env": loaded_env}), 500


@https_fn.on_request()
async def send_direct_notification(request: https_fn.Request):
    """
    Send a direct push notification to a single device.
    Body (JSON): {"token": "...", "title": "...", "body": "..."}
    """
    if not apns_sender:
        return jsonify({"error": "APNsSender not initialized"}), 500

    try:
        body = request.get_json(force=True, silent=True) or {}
    except Exception:
        body = {}

    token = body.get("token")
    title = body.get("title")
    body_text = body.get("body")

    if not all([token, title, body_text]):
        return jsonify({"error": "token, title, and body are required"}), 400

    response = await apns_sender.send_direct(token, title, body_text)
    if response:
        return jsonify({"success": True, "status": response.status})
    else:
        return jsonify({"success": False}), 500


@https_fn.on_request()
async def send_broadcast_notification(request: https_fn.Request):
    """
    Send a broadcast push notification to all devices.
    Body (JSON): {"title": "...", "body": "..."}
    """
    if not apns_sender:
        return jsonify({"error": "APNsSender not initialized"}), 500
    
    try:
        body = request.get_json(force=True, silent=True) or {}
    except Exception:
        body = {}

    title = body.get("title")
    body_text = body.get("body")

    if not all([title, body_text]):
        return jsonify({"error": "title and body are required"}), 400

    db = firestore.client()
    devices_ref = db.collection("devices")
    docs = devices_ref.stream()
    tokens = [doc.to_dict().get("token") for doc in docs]
    tokens = [token for token in tokens if token]


    if not tokens:
        return jsonify({"error": "No device tokens found"}), 404

    responses = await apns_sender.send_broadcast(tokens, title, body_text)
    
    results = []
    for resp in responses:
        results.append({
            "token": resp.device_token,
            "status": resp.status,
            "description": resp.description,
        })
        
    return jsonify({"success": True, "results": results})

