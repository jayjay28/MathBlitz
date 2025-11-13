# Cloud Function for Faster Multiplayer Answer Processing

## 1. Objective

To significantly reduce the perceived latency when a player answers a question in a multiplayer match. This is achieved by moving the answer resolution logic from the client devices to a server-side Cloud Function, creating a faster and more authoritative game flow.

## 2. The Problem: Client-Side Latency

The current implementation uses a client-led approach to determine the winner of a round. This creates a noticeable delay due to multiple required network round trips:

1.  **Client A Submits:** The answer is written to Firestore. (Trip 1)
2.  **Fan-Out:** Firestore notifies all connected clients of the new answer. (Trip 2)
3.  **Client Race:** All clients receive the answer and "race" to execute a secure Firestore transaction to claim the win. (Trip 3)
4.  **Winner Announced:** The server confirms the transaction winner and notifies all clients of the updated game state. (Trip 4)

This chain of events, while secure, is inherently slow from a user's perspective.

## 3. The Solution: Server-Side Logic with a Cloud Function

By using a Cloud Function triggered by a new answer, we can consolidate the logic on the server, reducing the process to its essential steps:

1.  **Client A Submits:** The answer is written to Firestore. (Trip 1)
2.  **Cloud Function Executes:** A function on the server is immediately triggered. It validates the answer and runs a transaction to update the winner and score, all within Google's low-latency network.
3.  **Winner Announced:** The server notifies all clients of the updated game state. (Trip 2)

This approach cuts the network round trips in half and eliminates the client-side "race," resulting in a much faster and more responsive experience.

## 4. Implementation Guide

### Step 1: Create and Deploy the Cloud Function

This function should be written in Node.js/TypeScript and deployed to your Firebase project.

**Trigger:** `onCreate` on the Firestore path `/games/{gameId}/rounds/{roundId}/answers/{answerId}`.

**`index.ts` (Example Cloud Function)**
```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const resolveMultiplayerAnswer = functions.firestore
  .document("/games/{gameId}/rounds/{roundId}/answers/{answerId}")
  .onCreate(async (snapshot, context) => {
    const { gameId, roundId } = context.params;
    const answerData = snapshot.data();

    // Ensure data exists
    if (!answerData) {
      console.log("No answer data found.");
      return;
    }

    const roundRef = db.collection("games").doc(gameId).collection("rounds").doc(roundId);
    const playerRef = db.collection("games").doc(gameId).collection("players").doc(answerData.playerId);

    try {
      await db.runTransaction(async (transaction) => {
        const roundDoc = await transaction.get(roundRef);
        if (!roundDoc.exists) {
          throw new Error("Round document does not exist!");
        }

        const roundData = roundDoc.data()!;

        // --- Validation Logic ---

        // 1. Check if a winner has already been decided for this round.
        if (roundData.firstCorrectPlayerId) {
          console.log(`Round already won by ${roundData.firstCorrectPlayerId}. Aborting.`);
          return;
        }

        // 2. Check if the answer is for the correct question.
        if (roundData.questionIndex !== answerData.questionIndex) {
          console.log(`Answer for wrong question index (${answerData.questionIndex}). Aborting.`);
          return;
        }

        // 3. Check if the answer value is correct.
        const problem = roundData.problem;
        const isCorrect = problem.a * problem.b === answerData.value;
        if (!isCorrect) {
          console.log(`Answer ${answerData.value} is incorrect. Aborting.`);
          return;
        }

        // --- Update Logic ---
        // If all checks pass, this is the winner.
        console.log(`Correct answer from ${answerData.playerId}. Locking round.`);

        // Lock the round by setting the winner ID
        transaction.update(roundRef, {
          firstCorrectPlayerId: answerData.playerId,
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Increment the player's score
        transaction.update(playerRef, {
          score: admin.firestore.FieldValue.increment(1),
        });
      });
    } catch (e) {
      console.error("Answer resolution transaction failed: ", e);
    }
  });
```

### Step 2: Modify Client-Side Code (`SyncService.swift`)

With the logic moved to the server, the client's role becomes much simpler.

1.  **Remove Redundant Code:** The following functions and logic should be removed from `MultiplayerSyncService`:
    *   `processAnswerChanges(...)`
    *   `resolveFirstCorrect(...)`
    *   The `resolvingQuestionIndex` property.
    *   The `Task` block inside `listenToAnswers(...)` that calls `processAnswerChanges`.

2.  **Keep Essential Logic:**
    *   The `submit(answer:...)` function remains unchanged. Its job is simply to write the answer to Firestore, which triggers the Cloud Function.
    *   The `listenToCurrentRound(...)` listener is still essential. It will receive the `firstCorrectPlayerId` update from the server and automatically update the UI.
    *   The `advanceToNextQuestion(...)` function should be kept. The winning client (or a designated host client) should still be responsible for triggering this after observing the `firstCorrectPlayerId` change, preserving the "pause-then-advance" gameplay feel.

By making these changes, the client app becomes lighter, more secure, and the multiplayer experience will feel significantly faster.
