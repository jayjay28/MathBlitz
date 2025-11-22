
import asyncio
import os
from uuid import uuid4

from aioapns import APNs, NotificationRequest, PushType

class APNsSender:
    def __init__(self):
        key_path = os.environ.get("APNS_KEY_FILE")
        key_id = os.environ.get("APNS_KEY_ID")
        team_id = os.environ.get("APNS_TEAM_ID")
        topic = os.environ.get("APNS_TOPIC")
        use_sandbox_str = os.environ.get("APNS_USE_SANDBOX", "true").lower()
        use_sandbox = use_sandbox_str == "true"

        if not all([key_path, key_id, team_id, topic]):
            raise ValueError("Missing APNs configuration environment variables.")

        self.apns_client = APNs(
            key=self._load_key(key_path),
            key_id=key_id,
            team_id=team_id,
            topic=topic,
            use_sandbox=use_sandbox,
        )

    def _load_key(self, path: str) -> str:
        # In a deployed environment, the key might be stored directly in the env var
        if "-----BEGIN PRIVATE KEY-----" in path:
            return path
        with open(path, "r", encoding="utf-8") as fh:
            return fh.read()

    async def send_direct(self, device_token, title, body, sound="default", badge=1, meta=None):
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body,
                },
                "sound": sound,
                "badge": badge,
            },
        }
        if meta:
            payload["meta"] = meta

        request = NotificationRequest(
            device_token=device_token,
            message=payload,
            notification_id=str(uuid4()),
            push_type=PushType.ALERT,
            time_to_live=30,
        )

        try:
            response = await self.apns_client.send_notification(request)
            print(f"Status: {response.status}")
            if response.description:
                print(f"Description: {response.description}")
            return response
        except Exception as exc:
            print(f"Failed to send notification: {exc}")
            return None

    async def send_broadcast(self, device_tokens, title, body, sound="default", badge=1, meta=None):
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body,
                },
                "sound": sound,
                "badge": badge,
            },
        }
        if meta:
            payload["meta"] = meta

        requests = [
            NotificationRequest(
                device_token=device_token,
                message=payload,
                notification_id=str(uuid4()),
                push_type=PushType.ALERT,
                time_to_live=30,
            )
            for device_token in device_tokens
        ]

        # The aioapns library sends notifications concurrently
        responses = await asyncio.gather(*[self.apns_client.send_notification(req) for req in requests])
        
        for response in responses:
            print(f"Status: {response.status}")
            if response.description:
                print(f"Description: {response.description}")
        return responses
