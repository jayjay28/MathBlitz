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
    from firebase_admin import firestore
except ImportError:
    # This is a workaround for local development
    pass


try:
    firebase_admin.initialize_app()
except ValueError:
    pass

db = firestore.client()

# --- AI Problem Generation and Verification for Kids ---

def _call_openai_api(prompt, model="gpt-4-1106-preview", temperature=0.7, json_mode=False):
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set.")
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
    messages = [
        {"role": "system", "content": "You are a friendly and encouraging teacher's assistant for the Math Blitz game that creates fun and simple word problems for children aged 7-10."},
        {"role": "user", "content": prompt}
    ]
    data = {"model": model, "messages": messages, "temperature": temperature}
    if json_mode:
        data["response_format"] = {"type": "json_object"}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()['choices'][0]['message']['content']

def _generate_verified_ai_problem_for_kids(difficulty_level_str, max_retries=3, date_str=None):
    if date_str is None:
        date_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    prompt_guidelines = {
        "easy": "The problem should be a single-step addition or subtraction problem. Use small, whole numbers.",
        "medium": "The problem should involve two steps, like addition and then subtraction, or simple multiplication.",
        "hard": "The problem should involve multiple steps or a simple division problem. The answer must be a whole number."
    }

    themes = {
        "easy": ["sharing toys", "counting animals", "eating snacks"],
        "medium": ["saving money", "at the park", "baking cookies"],
        "hard": ["school fair", "team sports", "planning a party"]
    }

    base_generation_prompt = """You are a friendly and encouraging teacher's assistant for a fun kids' math game called 'Math Blitz'. Your goal is to generate a 'Daily Challenge' word problem for {date_str} that is easy for a 7-10 year old to understand.

The problem must be straightforward and not a trick question.

**Difficulty:** {difficulty_level_str}
**Theme:** {theme}
**Guidelines:** {guidelines}

Based on the difficulty and guidelines, generate a fun and simple word problem. The answer must be a single, positive, whole number.

Return the response as a valid JSON object with ONLY the following three keys:
1. "prompt": A string containing the word problem.
2. "answer": A number representing the correct answer.
3. "detailed_explanation": A string explaining the simple steps to solve the problem. For example, 'You start with 10 cookies, then you eat 3. So, 10 - 3 = 7 cookies left.'"""

    for attempt in range(max_retries):
        print(f"AI Kids Word Problem Generation for {difficulty_level_str}: Attempt {attempt + 1}")
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
            initial_answer = int(generated_data['answer'])
            detailed_explanation = generated_data['detailed_explanation']

            if initial_answer < 0:
                print(f"Generated answer is negative ({initial_answer}). Retrying for a positive answer.")
                continue

            verification_prompt = f"Solve this word problem and provide only the final numeric answer as an integer, with no other text or explanation: {generated_prompt}"
            raw_verification_response = _call_openai_api(verification_prompt, temperature=0)
            
            cleaned_response = re.sub(r'[^\d]', '', raw_verification_response)
            verified_answer = int(cleaned_response)

            if initial_answer == verified_answer:
                print(f"AI verification successful for kids {difficulty_level_str}. Prompt: '{generated_prompt}', Answer: {initial_answer}")
                return generated_prompt, initial_answer, detailed_explanation
            else:
                print(f"AI answer mismatch for kids {difficulty_level_str}. Initial: {initial_answer}, Verified: {verified_answer}. Retrying...")
        except (requests.exceptions.RequestException, json.JSONDecodeError, KeyError, ValueError) as e:
            print(f"Error during AI generation/verification for kids {difficulty_level_str}: {e}. Retrying...")
    
    raise ValueError(f"Failed to generate a valid and verified AI word problem for kids {difficulty_level_str} after multiple attempts.")


def _generate_challenge_for_difficulty_for_kids(date_str, difficulty):
    """Generates a kids' challenge for a given difficulty using the AI generator."""
    
    prompt, answer, detailed_explanation = _generate_verified_ai_problem_for_kids(difficulty, date_str=date_str)
    
    if difficulty == "easy":
        title = "Fun Times"
        time_limit_seconds = 60
        base_points = 50
    elif difficulty == "medium":
        title = "Brainy Puzzler"
        time_limit_seconds = 75
        base_points = 75
    else: # hard
        title = "Super Solver"
        time_limit_seconds = 90
        base_points = 100

    choices = set()
    choices.add(float(answer))
    choices.add(float(answer + random.choice([-1, 1, 2, -2])))
    if answer > 5:
        choices.add(float(answer + random.choice([-5, 5])))
    
    while len(choices) < 4:
        new_decoy = float(answer + random.randint(-10, 10))
        if new_decoy >= 0 and new_decoy not in choices:
            choices.add(new_decoy)
    
    final_choices = list(choices)
    random.shuffle(final_choices)
    correct_index = final_choices.index(float(answer))

    challenge = {
        "id": f"ai_generated_kids_{date_str}_{difficulty}-{random.randint(1000, 9999)}",
        "title": title,
        "difficulty": difficulty,
        "category": "Word Problem",
        "tags": ["kids", "fun", difficulty],
        "date_scheduled": date_str,
        "prompt": prompt,
        "answer_type": "multiple_choice_numeric",
        "correct_answer": float(answer),
        "numpad": {"max_digits": 3, "allow_negative": False, "allow_decimal": False},
        "multiple_choice": {"enabled": True, "choices": final_choices, "correct_choice_index": correct_index},
        "time_limit_seconds": time_limit_seconds,
        "scoring": {"base_points": base_points},
        "explanation": detailed_explanation
    }
    return challenge

@scheduler_fn.on_schedule(schedule="every day 06:05", timezone="America/New_York")
def generate_kids_daily_challenges(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Generates the daily challenges for kids for all difficulty levels and saves them to Firestore.
    """
    try:
        today_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        difficulties = ["easy", "medium", "hard"]
        challenges = []
        for difficulty in difficulties:
            challenge = _generate_challenge_for_difficulty_for_kids(today_iso, difficulty)
            doc_id = challenge["id"]
            db.collection("daily_challenges_kids").document(doc_id).set(challenge)
            challenges.append(challenge)
        
        print(json.dumps({"status": "success", "kids_challenges_generated": len(challenges)}))

    except Exception as e:
        print(f"An error occurred in generate_kids_daily_challenges: {e}")
        raise
