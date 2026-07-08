import json
import pathlib
import random


OUT = pathlib.Path("assets/content")
OUT.mkdir(parents=True, exist_ok=True)
random.seed(7)

CATEGORIES = [
    {"id": 1, "slug": "restaurant", "title": "Restaurant", "description": "Ordering food, drinks, and handling service conversations."},
    {"id": 2, "slug": "airport", "title": "Airport", "description": "Check-in, security, boarding, and travel help."},
    {"id": 3, "slug": "business", "title": "Business", "description": "Meetings, deadlines, updates, and professional small talk."},
    {"id": 4, "slug": "daily-life", "title": "Daily Life", "description": "Home, routines, errands, and casual conversation."},
    {"id": 5, "slug": "interview", "title": "Interview", "description": "Job interviews, introductions, and career stories."},
    {"id": 6, "slug": "shopping", "title": "Shopping", "description": "Prices, sizes, returns, and product questions."},
    {"id": 7, "slug": "health", "title": "Health", "description": "Appointments, symptoms, and pharmacy conversations."},
    {"id": 8, "slug": "travel", "title": "Travel", "description": "Hotels, directions, tickets, and local recommendations."},
    {"id": 9, "slug": "education", "title": "Education", "description": "Classroom, study, exams, and academic discussion."},
    {"id": 10, "slug": "social", "title": "Social", "description": "Friends, invitations, opinions, and storytelling."},
    {"id": 11, "slug": "technology", "title": "Technology", "description": "Devices, apps, support, and online services."},
    {"id": 12, "slug": "finance", "title": "Finance", "description": "Banking, payments, budgets, and bills."},
]

VERBS = {
    "Restaurant": "Order politely",
    "Airport": "Ask for travel help",
    "Business": "Explain clearly",
    "Daily Life": "Describe routines",
    "Interview": "Answer confidently",
    "Shopping": "Compare options",
    "Health": "Describe symptoms",
    "Travel": "Plan a trip",
    "Education": "Discuss learning",
    "Social": "Share opinions",
    "Technology": "Ask for support",
    "Finance": "Discuss payments",
}


def write_json(name, rows):
    with (OUT / name).open("w", encoding="utf-8") as file:
        json.dump(rows, file, indent=2, ensure_ascii=False)


def build_lessons():
    base_lessons = [
        ("Ordering Coffee", "Restaurant", "Order your favorite drink and ask about the menu.", "Beginner", 8, 0.85, 1),
        ("At the Airport (Check-in)", "Airport", "Check in for a flight and ask about baggage.", "Beginner", 10, 0.35, 1),
        ("Team Standup Update", "Business", "Share yesterday, today, and blockers clearly.", "Intermediate", 12, 0.15, 1),
        ("Weekend Storytelling", "Daily Life", "Tell a short story about your weekend in sequence.", "Intermediate", 9, 0.0, 0),
        ("Job Interview Intro", "Interview", "Introduce yourself and explain your experience.", "Intermediate", 14, 0.0, 1),
    ]
    lessons = []
    for index, row in enumerate(base_lessons, 1):
        title, category, description, difficulty, minutes, progress, recommended = row
        lessons.append({
            "id": index,
            "title": title,
            "category": category,
            "description": description,
            "difficulty": difficulty,
            "estimated_minutes": minutes,
            "progress": progress,
            "recommended": recommended,
        })
    for index in range(6, 2001):
        category = CATEGORIES[(index - 6) % len(CATEGORIES)]["title"]
        level = ["Beginner", "Elementary", "Intermediate", "Upper Intermediate", "Advanced"][(index - 6) % 5]
        lessons.append({
            "id": index,
            "title": f"{category} Speaking Scenario {index - 5:04d}",
            "category": category,
            "description": f"{VERBS[category]} in a realistic {category.lower()} situation.",
            "difficulty": level,
            "estimated_minutes": 6 + ((index - 6) % 12),
            "progress": 0.0,
            "recommended": 1 if index % 41 == 0 else 0,
        })
    return lessons


def main():
    write_json("categories.json", CATEGORIES)
    write_json("lessons.json", build_lessons())

    vocabulary = [
        {"id": 1, "word": "departure", "topic": "Airport", "mastery": 0.72},
        {"id": 2, "word": "reservation", "topic": "Restaurant", "mastery": 0.81},
        {"id": 3, "word": "deadline", "topic": "Business", "mastery": 0.64},
    ]
    for index in range(4, 10001):
        category = CATEGORIES[(index - 4) % len(CATEGORIES)]
        vocabulary.append({
            "id": index,
            "word": f"{category['slug']}-word-{index:05d}",
            "topic": category["title"],
            "mastery": round((index % 100) / 100, 2),
        })
    write_json("vocabulary.json", vocabulary)

    openings = [
        "Hello! Welcome to our coffee shop. What would you like to order?",
        "Good morning. How can I help you today?",
        "Thanks for coming in. What would you like to talk about?",
        "Hi there. Tell me what you need.",
    ]
    dialogues = []
    for index in range(1, 5001):
        lesson_id = ((index - 1) // 5) % 2000 + 1
        turn = (index - 1) % 5 + 1
        speaker = "tutor" if turn % 2 else "learner"
        text = openings[(index - 1) % len(openings)] if turn == 1 else f"{speaker.title()} practice line {turn} for lesson {lesson_id}."
        if index == 2:
            text = "I would like a cappuccino, please."
        dialogues.append({
            "id": index,
            "lesson_id": lesson_id,
            "turn_order": turn,
            "speaker": speaker,
            "text": text,
            "intent": ["opening", "order", "follow_up", "choice", "closing"][turn - 1],
        })
    write_json("dialogues.json", dialogues)

    exercise_types = ["fill_blank", "roleplay", "correction", "listening", "translation"]
    exercises = []
    for index in range(1, 20001):
        lesson_id = ((index - 1) // 10) % 2000 + 1
        exercises.append({
            "id": index,
            "lesson_id": lesson_id,
            "exercise_type": exercise_types[(index - 1) % len(exercise_types)],
            "prompt": "Complete: I ___ like a cappuccino, please." if index == 1 else f"Practice item {index} for lesson {lesson_id}.",
            "answer": "would" if index == 1 else f"Sample answer {index}",
            "hint": "Use a polite modal verb." if index == 1 else "Answer naturally and keep your sentence clear.",
            "difficulty": ["Beginner", "Intermediate", "Advanced"][index % 3],
        })
    write_json("exercises.json", exercises)

    review_cards = []
    for index in range(1, 3001):
        lesson_id = ((index - 1) // 3) % 2000 + 1
        review_cards.append({
            "id": index,
            "lesson_id": lesson_id,
            "front": "How do you politely order coffee?" if index == 1 else f"Review prompt {index}",
            "back": "I would like a coffee, please." if index == 1 else f"Review answer {index}",
            "card_type": ["phrase", "vocabulary", "correction"][index % 3],
        })
    write_json("review_cards.json", review_cards)

    drills = []
    for index in range(1, 1001):
        lesson_id = ((index - 1) // 2) % 2000 + 1
        drills.append({
            "id": index,
            "lesson_id": lesson_id,
            "phrase": "I would like a cappuccino." if index == 1 else f"Pronunciation phrase {index}",
            "phonetic_hint": "Stress WOULD and CAP-pu-chi-no." if index == 1 else "Speak slowly, then repeat naturally.",
            "target_sound": ["w", "k", "th", "r", "v"][index % 5],
        })
    write_json("pronunciation_drills.json", drills)

    phrases = []
    base_phrases = ["I would like...", "Could I have...", "For here, please.", "To go, please."]
    for index in range(1, 1501):
        phrases.append({
            "id": index,
            "lesson_id": ((index - 1) // 4) % 2000 + 1,
            "phrase": base_phrases[(index - 1) % len(base_phrases)] if index <= 4 else f"Common phrase {index}",
            "formality": ["polite", "neutral", "casual"][index % 3],
            "usage_note": "Useful in real conversation.",
        })
    write_json("common_phrases.json", phrases)

    patterns = []
    for index in range(1, 501):
        patterns.append({
            "id": index,
            "mistake_type": ["article_usage", "politeness", "past_tense", "word_order", "prepositions"][index % 5],
            "pattern": "I want cappuccino" if index == 1 else f"Pattern {index}",
            "correction": "I would like a cappuccino, please." if index == 1 else f"Correction {index}",
            "explanation": "Use an article before singular countable nouns." if index == 1 else "Use the clearer natural English pattern.",
        })
    write_json("grammar_patterns.json", patterns)


if __name__ == "__main__":
    main()
