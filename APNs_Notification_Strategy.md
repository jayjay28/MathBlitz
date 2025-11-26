# APNs Notification Strategy

This document outlines the strategy for refactoring our push notification system to rely exclusively on direct APNs notifications, using the `aioapns` library. This change will simplify our backend, remove the dependency on Firebase Cloud Messaging, and give us more control over the notification process.

## 1. The `APNsSender` Class

We will create a reusable `APNsSender` class, based on the logic in `scripts/broadcast/send_apns.py`. This class will be responsible for sending all APNs notifications.

### Features:

*   **Initialization:** The class will be initialized with the necessary APNs credentials (key, key ID, team ID, and topic) from environment variables.
*   **Direct Send:** A `send_direct(device_token, title, body, ...)` method will send a notification to a single device token.
*   **Broadcast Send:** A `send_broadcast(device_tokens, title, body, ...)` method will send the same notification to a list of device tokens.
*   **Asynchronous:** The class will be fully asynchronous, leveraging the `aioapns` library.

## 2. Cloud Function Refactoring

We will refactor our existing Cloud Functions to use the new `APNsSender` class.

*   **`notify_high_score_overtake`:** This function will be modified to use `APNsSender.send_direct()` to send notifications to the overtaken players. It will no longer use Firebase Messaging.
*   **`send_direct_notification` & `send_broadcast_notification`:** These HTTP-triggered functions will use the `APNsSender` class to send notifications.

## 3. Removal of Firebase Messaging

We will completely remove the Firebase Cloud Messaging implementation from our Python backend. This includes:

*   Removing any `firebase_admin.messaging` calls.
*   Removing the `messaging` import from `firebase_admin`.

## 4. New Notification Architecture

The new architecture will be simpler and more direct:

1.  **Client-side:** The iOS app will continue to register for remote notifications and send the device token to our backend, where it will be stored in the `devices` collection in Firestore.
2.  **Backend:**
    *   When a notification needs to be sent (e.g., a high score is overtaken), the relevant Cloud Function will be triggered.
    *   The function will fetch the necessary device token(s) from the `devices` collection.
    *   It will then use the `APNsSender` class to send the notification directly to the APNs servers.

This strategy will give us a more streamlined and cost-effective notification system that we have full control over.
