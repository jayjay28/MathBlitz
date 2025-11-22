import asyncio
from flask import jsonify
from firebase_admin import initialize_app, firestore
from firebase_functions import https_fn

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


