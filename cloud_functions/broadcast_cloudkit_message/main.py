import json
import os
import time
from typing import Any, Dict, Optional

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
