from firebase_admin import initialize_app, firestore
from firebase_functions import firestore_fn

# Initialize Firebase Admin once per instance (safe when imported multiple times).
try:
    initialize_app()
except ValueError:
    pass

@firestore_fn.on_document_created(document="/games/{gameId}/rounds/{roundId}/answers/{answerId}", region="us-central1")
def resolvemultiplayeranswer(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """A Cloud Function that resolves a multiplayer answer in real-time."""

    db = firestore.client()
    print("resolveMultiplayerAnswer invoked", event.params)
    
    game_id = event.params.get("gameId")
    round_id = event.params.get("roundId")
    
    answer_data = event.data.to_dict()

    if not answer_data:
        print("No answer data found.")
        return

    player_id = answer_data.get("playerId")
    if not player_id:
        print("Player ID missing from answer data.")
        return

    round_ref = db.collection("games").document(game_id).collection("rounds").document(round_id)
    player_ref = db.collection("games").document(game_id).collection("players").document(player_id)

    try:
        @firestore.transactional
        def _resolve_answer(transaction):
            round_doc = round_ref.get(transaction=transaction)
            if not round_doc.exists:
                print("Error: Round document does not exist!")
                return

            round_data = round_doc.to_dict()

            # --- Validation Logic ---

            # 1. Check if a winner has already been decided for this round.
            if round_data.get("firstCorrectPlayerId"):
                print(f"Round already won by {round_data.get('firstCorrectPlayerId')}. Aborting.")
                return

            # 2. Check if the answer is for the correct question.
            if round_data.get("questionIndex") != answer_data.get("questionIndex"):
                print(f"Answer for wrong question index ({answer_data.get('questionIndex')}). Aborting.")
                return

            # 3. Check if the answer value is correct.
            problem = round_data.get("problem", {})
            is_correct = problem.get("a", 0) * problem.get("b", 0) == answer_data.get("value")
            if not is_correct:
                print(f"Answer {answer_data.get('value')} is incorrect. Aborting.")
                return

            # --- Update Logic ---
            # If all checks pass, this is the winner.
            print(f"Correct answer from {player_id}. Locking round.")

            # Lock the round by setting the winner ID
            transaction.update(round_ref, {
                "firstCorrectPlayerId": player_id,
                "lockedAt": firestore.SERVER_TIMESTAMP,
            })

            # Increment the player's score
            transaction.update(player_ref, {
                "score": firestore.Increment(1),
            })

        # Run the transaction
        _resolve_answer(db.transaction())

    except Exception as e:
        print(f"Answer resolution transaction failed: {e}")
