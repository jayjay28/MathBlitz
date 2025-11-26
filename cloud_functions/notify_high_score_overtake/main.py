import asyncio
from firebase_admin import initialize_app, firestore
from firebase_functions import firestore_fn

from apns_sender import APNsSender

# Initialize Firebase Admin once per instance (safe when imported multiple times).
try:
    initialize_app()
except ValueError:
    pass


MODE_LABELS = {
    "kids": "Kids",
    "adults": "Adults",
}

MAX_NOTIFICATION_TARGETS = 5

@firestore_fn.on_document_written(document="leaderboards/{mode}/entries/{playerId}", region="us-central1")
def notify_high_score_overtake(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    print("notify_high_score_overtake function triggered.")

    db = firestore.client()
    before_data = event.data.before.to_dict() if event.data.before else {}
    after_snapshot = event.data.after
    if after_snapshot is None:
        print("No after data found (document deleted).")
        return
    after_data = after_snapshot.to_dict()
    if not after_data:
        print("After data is empty.")
        return

    new_score = after_data.get("score")
    previous_score = before_data.get("score", 0)
    if not isinstance(new_score, int) or new_score <= (previous_score or 0):
        print(f"New score ({new_score}) not an improvement over previous ({previous_score}). Aborting.")
        return

    mode = event.params.get("mode")
    player_id = event.params.get("playerId")
    if not mode or not player_id:
        print("Mode or Player ID missing from event parameters. Aborting.")
        return

    try:
        leaderboard_docs = list(
            db.collection("leaderboards")
            .document(mode)
            .collection("entries")
            .order_by("score", direction=firestore.Query.DESCENDING)
            .order_by("updatedAt", direction=firestore.Query.DESCENDING)
            .limit(50)
            .stream()
        )
    except Exception as exc:
        print(f"Failed to load leaderboard for notifications: {exc}")
        return

    overtaken_docs = []
    for doc in leaderboard_docs:
        if doc.id == player_id:
            continue
        if len(overtaken_docs) >= MAX_NOTIFICATION_TARGETS:
            break
        doc_data = doc.to_dict() or {}
        doc_score = doc_data.get("score", 0)
        if not isinstance(doc_score, int):
            continue
        if doc_score <= (previous_score or 0):
            break
        if doc_score < new_score:
            overtaken_docs.append(doc_data | {"playerId": doc.id})

    if not overtaken_docs:
        print("No players were overtaken. Aborting notification send.")
        return
    
    print(f"Found {len(overtaken_docs)} overtaken players: {overtaken_docs}")

    challenger_name = after_data.get("displayName", "Another player")
    mode_label = MODE_LABELS.get(mode, mode.title())

    async def send_notifications():
        try:
            apns_sender = APNsSender()
        except ValueError as e:
            print(f"Failed to initialize APNsSender: {e}")
            print("Ensure APNS_KEY_CONTENT (or APNS_KEY_FILE), APNS_KEY_ID, APNS_TEAM_ID, and APNS_TOPIC are set.")
            return
        except Exception as e:
            print(f"Unexpected error initializing APNsSender: {e}")
            return
        
        for doc in overtaken_docs:
            target_id = doc.get("playerId")
            if not target_id:
                print(f"Skipping notification for a doc with no target_id: {doc}")
                continue
            tokens = collect_tokens_for_users(db, [target_id])
            if not tokens:
                print(f"No tokens found for target_id: {target_id}. Skipping notification.")
                continue
            
            print(f"Attempting to send notification to {len(tokens)} tokens for player {target_id}.")
            notification_body = f"{challenger_name} scored {new_score} pts in {mode_label} mode."
            title = "Your high score was beaten!"
            
            try:
                await apns_sender.send_broadcast(tokens, title, notification_body)
                print(f"Notification sent attempt for {target_id} completed.")
            except Exception as e:
                print(f"Failed to send notification to {target_id}: {e}")
                continue
    
    asyncio.run(send_notifications())

def collect_tokens_for_users(db, user_ids):
    tokens = []
    for user_id in user_ids:
        print(f"Fetching tokens for user_id: {user_id}") # Added print
        docs = db.collection("profiles").document(user_id).collection("deviceTokens").stream()
        for doc in docs:
            token = doc.to_dict().get("token")
            # print("token doc", doc.id, data)
            if token:
                tokens.append(token)
                print(f"Found token for {user_id}: {token}") # Added print
            else:
                print(f"Document {doc.id} for user {user_id} has no 'token' field.")
    # Deduplicate tokens
    seen = set()
    unique = []
    for t in tokens:
        if t not in seen:
            unique.append(t)
            seen.add(t)
    print(f"Collected {len(unique)} unique tokens for user_ids: {user_ids}") # Added print
    return unique
