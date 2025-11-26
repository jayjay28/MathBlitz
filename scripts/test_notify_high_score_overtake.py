#!/usr/bin/env python3
"""Simple script to write a test leaderboard entry to Firestore."""

import os
import time
import firebase_admin
from firebase_admin import credentials, firestore

# Path to Firebase service account credentials
CREDENTIALS_PATH = "/Users/clyonjackson/Documents/MathBlitz Project/mathblitz-79f43-firebase-adminsdk-fbsvc-34ca0da8e7.json"

# Initialize Firebase
try:
    firebase_admin.get_app()
except ValueError:
    # Not initialized yet
    if os.path.exists(CREDENTIALS_PATH):
        # Use service account key file
        cred = credentials.Certificate(CREDENTIALS_PATH)
        print(f"Using service account: {CREDENTIALS_PATH}")
    elif os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'):
        # Use service account key file from env var
        cred = credentials.Certificate(os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'))
    else:
        # Use Application Default Credentials (gcloud auth)
        cred = credentials.ApplicationDefault()
    
    firebase_admin.initialize_app(cred, {
        'projectId': 'mathblitz-79f43',
    })

db = firestore.client()

# Write a test entry
mode = "adults"
player_id = f"test_player_{int(time.time())}"
new_score = 1000

entry_data = {
    "score": new_score,
    "playerId": player_id,
    "displayName": "Test Player",
    "updatedAt": firestore.SERVER_TIMESTAMP
}

leaderboard_ref = db.collection("leaderboards").document(mode).collection("entries")
leaderboard_ref.document(player_id).set(entry_data)

print(f"✓ Created entry: {player_id} with score {new_score} in {mode} mode")
