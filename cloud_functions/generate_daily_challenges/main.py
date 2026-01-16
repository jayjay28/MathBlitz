import datetime
import random
import json
import asyncio
import os
import re
import requests
import firebase_admin
from firebase_functions import scheduler_fn

try:
    firebase_admin.initialize_app()
except ValueError:
    pass

db = firestore.client()

# --- AI Problem Generation and Verification ---

def _call_openai_api(prompt, model="gpt-4-1106-preview", temperature=0.7, json_mode=False):
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set.")
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
    messages = [
        {"role": "system", "content": "You are a helpful assistant for the Math Blitz game that creates tricky word problems."},
        {"role": "user", "content": prompt}
    ]
    data = {"model": model, "messages": messages, "temperature": temperature}
    if json_mode:
        data["response_format"] = {"type": "json_object"}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()['choices'][0]['message']['content']

def _generate_verified_ai_problem(difficulty_level_str, max_retries=3, date_str=None):
    if date_str is None:
        date_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    prompt_guidelines = {
        "easy": "The problem should be a classic 'System 1' trap that relies on a common mathematical misconception. The 'bat and ball' problem is a perfect example.",
        "medium": "The problem should involve a few simple steps or a slightly more complex scenario. It should still be a 'System 1' trap, but one that requires more careful thought to solve.",
        "hard": "The problem should require more advanced logic or mathematical concepts. It should be a true 'System 2' problem that is difficult to solve even with careful thought. Avoid simple 'gotcha' questions."
    }

    themes = {
        "easy": ["price comparison", "simple logic", "rates and speed", "age puzzles"],
        "medium": ["probability", "conditional logic", "percentage puzzles", "logic sequences"],
        "hard": ["advanced probability", "combinatorics", "optimization puzzles", "cryptic algebra"]
    }

    base_generation_prompt = """You are a Senior Mathematics Curriculum Designer for a viral brain-training app called 'Math Blitz'. Your goal is to generate a 'Daily Challenge' word problem for {date_str} that is highly engaging and designed to be shared and debated on social media.

The problem must be a 'System 1' trap: a question where the intuitive, gut-reaction answer is wrong, but a logical, 'System 2' answer is correct. Focus on common mathematical misconceptions, logical fallacies, or misinterpretations that a large percentage of adults get wrong on their first try.

**Originality Clause:** Do NOT use common, widely-known brain teasers. For example, avoid variations of the 'bat and ball' problem, the 'lily pad' problem, the 'car and goat' (Monty Hall) problem, or the 'snail in the well' problem. Your problem should feel fresh and original.

**Difficulty:** {difficulty_level_str}
**Theme:** {theme}
**Guidelines:** {guidelines}

Based on the difficulty and guidelines, generate a clever and concise word problem. The answer must be a single number.

Return the response as a valid JSON object with ONLY the following three keys:
1. "prompt": A string containing the word problem.
2. "answer": A number representing the correct answer.
3. "detailed_explanation": A string explaining the logic and steps to solve the problem, including why the intuitive answer is likely incorrect."""

    for attempt in range(max_retries):
        print(f"AI Word Problem Generation for {difficulty_level_str}: Attempt {attempt + 1}")
        try:
            guidelines = prompt_guidelines.get(difficulty_level_str, "")
            theme = random.choice(themes.get(difficulty_level_str, ["general"]))
            generation_prompt_with_difficulty = base_generation_prompt.format(
                date_str=date_str,
                difficulty_level_str=difficulty_level_str,
                theme=theme,
                guidelines=guidelines
            )
            raw_generation_response = _call_openai_api(generation_prompt_with_difficulty, json_mode=True)
            generated_data = json.loads(raw_generation_response)
            generated_prompt = generated_data['prompt']
            initial_answer = float(generated_data['answer'])
            detailed_explanation = generated_data['detailed_explanation']

            verification_prompt = f"Solve this word problem and provide only the final numeric answer as an integer or float, with no other text or explanation: {generated_prompt}"
            raw_verification_response = _call_openai_api(verification_prompt, temperature=0)
            
            # Sanitize the response to remove non-numeric characters before converting to float
            cleaned_response = re.sub(r'[^\d.]', '', raw_verification_response)
            verified_answer = float(cleaned_response)

            if abs(initial_answer - verified_answer) < 0.001:
                print(f"AI verification successful for {difficulty_level_str}. Prompt: '{generated_prompt}', Answer: {initial_answer}")
                return generated_prompt, initial_answer, detailed_explanation
            else:
                print(f"AI answer mismatch for {difficulty_level_str}. Initial: {initial_answer}, Verified: {verified_answer}. Retrying...")
        except (requests.exceptions.RequestException, json.JSONDecodeError, KeyError, ValueError) as e:
            print(f"Error during AI generation/verification for {difficulty_level_str}: {e}. Retrying...")
    
    raise ValueError(f"Failed to generate a valid and verified AI word problem for {difficulty_level_str} after multiple attempts.")


def _generate_challenge_for_difficulty(date_str, difficulty):
    """Generates a challenge for a given difficulty using the AI generator."""
    
    # Generate the core problem from the AI
    prompt, answer, detailed_explanation = _generate_verified_ai_problem(difficulty, date_str=date_str)
    
    # Set metadata based on difficulty
    if difficulty == "easy":
        title = "Brain Tease"
        tags = ["logic", "word problem", "trap"]
        time_limit_seconds = 30
        base_points = 75
    elif difficulty == "medium":
        title = "Mind Bender"
        tags = ["logic", "word problem", "critical thinking"]
        time_limit_seconds = 40
        base_points = 125
    else: # hard
        title = "Genius Puzzle"
        tags = ["logic", "puzzle", "viral", "challenge"]
        time_limit_seconds = 50
        base_points = 200

    # --- Dynamic Multiple Choice Generation ---
    choices = set()
    choices.add(answer)
    # Add plausible decoys
    choices.add(answer + random.choice([-1.0, 1.0, 2.0, -2.0]))
    if answer > 10:
        choices.add(answer + random.choice([-10.0, 10.0]))
        if answer == int(answer):
            str_ans = str(int(answer))
            if len(str_ans) == 2:
                swapped_ans = float(int(str_ans[1] + str_ans[0]))
                if abs(swapped_ans - answer) > 0.001: choices.add(swapped_ans)
    # Pad until we have 4 choices
    while len(choices) < 4:
        new_decoy = answer + random.uniform(-15.0, 15.0)
        if all(abs(new_decoy - c) > 0.1 for c in choices) and new_decoy > 0:
            choices.add(round(new_decoy, 1))
    
    final_choices = list(choices)
    random.shuffle(final_choices)
    correct_index = final_choices.index(answer)

    # --- Construct the final JSON object ---
    challenge = {
        "id": f"ai_generated_{date_str}_{difficulty}-{random.randint(1000, 9999)}",
        "title": title,
        "difficulty": difficulty,
        "category": "Word Problem",
        "tags": tags,
        "date_scheduled": date_str,
        "prompt": prompt,
        "answer_type": "multiple_choice_numeric",
        "correct_answer": answer,
        "numpad": {"max_digits": 5, "allow_negative": False, "allow_decimal": True},
        "multiple_choice": {"enabled": True, "choices": final_choices, "correct_choice_index": correct_index},
        "time_limit_seconds": time_limit_seconds,
        "scoring": {
            "base_points": base_points,
            "speed_bonus": {"enabled": True, "ideal_seconds": time_limit_seconds // 2, "max_bonus_points": base_points // 2}
        },
        "explanation": detailed_explanation
    }
    return challenge

# --- Main Cloud Function & Notification Logic ---

@scheduler_fn.on_schedule(schedule="every day 06:00", timezone="America/New_York")
def generate_daily_challenges(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Generates the daily challenges for all difficulty levels and saves them to Firestore.
    This function is scheduled to run every day at 6am.
    """
    try:
        # The function body remains largely the same
        today_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        difficulties = ["easy", "medium", "hard"]
        challenges = []
        for difficulty in difficulties:
            challenge = _generate_challenge_for_difficulty(today_iso, difficulty)
            doc_id = challenge["id"]
            db.collection("daily_challenges").document(doc_id).set(challenge)
            challenges.append(challenge)
        
        asyncio.run(_send_daily_challenge_notification(today_iso))
        
        # For scheduled functions, use standard Python print() for logging
        print(json.dumps({"status": "success", "challenges_generated": len(challenges)}))

    except Exception as e:
        # Log the error
        print(f"An error occurred: {e}")
        # Re-raise the exception to mark the function execution as a failure in the logs
        raise

async def _send_daily_challenge_notification(date_str):
    # ...
    pass

def _collect_all_device_tokens():
    # ...
    pass
