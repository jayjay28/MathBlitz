
import asyncio
import os

from dotenv import load_dotenv
from firebase_admin import initialize_app, firestore

from apns_sender import APNsSender

# Load environment variables from .env file
load_dotenv()

# Initialize Firebase Admin
try:
    initialize_app()
except ValueError:
    pass

# Get a test device token from environment variables
TEST_DEVICE_TOKEN = os.environ.get("TEST_DEVICE_TOKEN")


async def main():
    """
    Test the APNsSender class.
    """
    if not TEST_DEVICE_TOKEN:
        print("TEST_DEVICE_TOKEN environment variable not set. Skipping direct send.")
        return

    # Initialize the APNsSender
    try:
        sender = APNsSender()
    except ValueError as e:
        print(f"Failed to initialize APNsSender: {e}")
        return

    # --- Test Direct Send ---
    print("--- Testing Direct Send ---")
    await sender.send_direct(
        TEST_DEVICE_TOKEN,
        title="Direct Test",
        body="This is a direct test notification.",
    )

    # --- Test Broadcast Send ---
    print("\n--- Testing Broadcast Send ---")
    db = firestore.client()
    devices_ref = db.collection("devices")
    docs = devices_ref.stream()
    tokens = [doc.to_dict().get("token") for doc in docs]
    tokens = [token for token in tokens if token]

    if not tokens:
        print("No device tokens found in Firestore. Skipping broadcast send.")
        return

    await sender.send_broadcast(
        tokens,
        title="Broadcast Test",
        body="This is a broadcast test notification.",
    )


if __name__ == "__main__":
    asyncio.run(main())
