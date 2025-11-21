"""
Send a direct APNs push using aioapns.

Requires:
- pip install aioapns
- Auth key (.p8), Key ID, Team ID, and topic (bundle id)

Environment defaults (override as needed):
  APNS_KEY_FILE   path to AuthKey_XXXX.p8
  APNS_KEY_ID     key id (e.g., 1A2B3C4D5E)
  APNS_TEAM_ID    Apple Developer team id
  APNS_TOPIC      app bundle id (e.g., MathBlitz)
  APNS_USE_SANDBOX true/false (default true)
"""

import asyncio
import os
from uuid import uuid4

from aioapns import APNs, NotificationRequest, PushType


DEVICE_TOKEN = "5c06196347836fc52db48fe31b1d1a1c2d3d9d4cc64739a4989bf35655d6e3d2"


def load_key(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


async def main() -> None:
    key_path = "devAuthKey_27P3227A58.p8"
    key_id = "27P3227A58"
    team_id = "E4AMNFD4MA"
    topic = "MathBlitz"
    use_sandbox = "true"

    apns_client = APNs(
        key=load_key(key_path),
        key_id=key_id,
        team_id=team_id,
        topic=topic,
        use_sandbox=use_sandbox,
    )

    payload = {
        "aps": {
            "alert": {
                "title": "Hello from aioapns",
                "body": "Direct APNs test push.",
            },
            "sound": "default",
            "badge": 1,
        },
        "meta": {"source": "scripts/broadcast/send_apns.py"},
    }

    request = NotificationRequest(
        device_token=DEVICE_TOKEN,
        message=payload,
        notification_id=str(uuid4()),
        push_type=PushType.ALERT,
        time_to_live=30,
    )

    try:
        response = await apns_client.send_notification(request)
        print(f"Status: {response.status}")
        if response.description:
            print(f"Description: {response.description}")
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to send notification: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
