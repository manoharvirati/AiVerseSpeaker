import hashlib
import json
import pathlib
import sqlite3


ROOT = pathlib.Path(__file__).resolve().parents[1]
OLD = ROOT / "assets" / "content"
SRC = ROOT / "data_source"
OUT = ROOT / "assets" / "database"


def read_old(name):
    with (OLD / name).open(encoding="utf-8") as file:
        return json.load(file)


def write_source(name, rows):
    SRC.mkdir(parents=True, exist_ok=True)
    with (SRC / name).open("w", encoding="utf-8") as file:
        json.dump(rows, file, indent=2, ensure_ascii=False)


def build_sources():
    categories = read_old("categories.json")
    old_lessons = read_old("lessons.json")
    known_titles = {row["title"] for row in categories}
    for row in old_lessons:
        if row["category"] not in known_titles:
            categories.append({
                "id": len(categories) + 1,
                "slug": row["category"].lower().replace(" ", "-"),
                "title": row["category"],
                "description": f"{row['category']} speaking practice.",
            })
            known_titles.add(row["category"])
    category_by_title = {row["title"]: row["id"] for row in categories}
    colors = ["#F57C00", "#1976D2", "#388E3C", "#7B1FA2", "#C2185B", "#455A64"]
    for index, row in enumerate(categories):
        row.setdefault("icon", row["slug"])
        row.setdefault("color", colors[index % len(colors)])
        row.setdefault("cefr", ["A1", "A2", "B1", "B2"][index % 4])

    lessons = [
        {
            "id": row["id"],
            "category_id": category_by_title[row["category"]],
            "title": row["title"],
            "objective": row["description"],
            "difficulty": row["difficulty"],
            "estimated_minutes": row["estimated_minutes"],
            "order_index": row["id"],
        }
        for row in old_lessons
    ]

    old_dialogues = read_old("dialogues.json")
    dialogues_by_lesson = {}
    for turn in old_dialogues:
        dialogues_by_lesson.setdefault(turn["lesson_id"], []).append(turn)
    dialogues = []
    dialogue_turns = []
    for index, lesson_id in enumerate(sorted(dialogues_by_lesson), 1):
        dialogue_id = 5000 + index
        dialogues.append({"id": dialogue_id, "lesson_id": lesson_id, "type": "conversation"})
        for turn in dialogues_by_lesson[lesson_id]:
            dialogue_turns.append({
                "id": turn["id"],
                "dialogue_id": dialogue_id,
                "turn_number": turn["turn_order"],
                "speaker": turn["speaker"],
                "text": turn["text"],
            })

    old_vocabulary = read_old("vocabulary.json")
    if len(old_vocabulary) < 10000:
        start = len(old_vocabulary) + 1
        for index in range(start, 10001):
            category = categories[(index - start) % len(categories)]
            old_vocabulary.append({
                "id": index,
                "word": f"{category['slug']}-word-{index:05d}",
                "topic": category["title"],
                "mastery": round((index % 100) / 100, 2),
            })
    vocabulary = []
    vocabulary_examples = []
    for row in old_vocabulary:
        audio_id = 300000 + row["id"]
        vocabulary.append({
            "id": row["id"],
            "word": row["word"],
            "meaning": f"Meaning of {row['word']}",
            "phonetic": "",
            "part_of_speech": "phrase" if "-" in row["word"] else "noun",
            "cefr": ["A1", "A2", "B1", "B2"][row["id"] % 4],
            "audio_id": audio_id,
        })
        vocabulary_examples.append({
            "id": row["id"],
            "vocabulary_id": row["id"],
            "example": f"Practice using {row['word']} in a sentence.",
        })

    old_grammar = read_old("grammar_patterns.json")
    grammar_patterns = [
        {
            "id": row["id"],
            "title": row["mistake_type"].replace("_", " ").title(),
            "rule": row["explanation"],
            "formula": row["pattern"],
            "cefr": ["A1", "A2", "B1", "B2"][row["id"] % 4],
        }
        for row in old_grammar
    ]

    old_exercises = read_old("exercises.json")
    exercises = []
    exercise_choices = []
    for row in old_exercises:
        exercises.append({
            "id": row["id"],
            "lesson_id": row["lesson_id"],
            "type": row["exercise_type"],
            "question": row["prompt"],
            "hint": row["hint"],
            "difficulty": row["difficulty"],
        })
        choices = [row["answer"], "Not this one", "Try another answer", "Incorrect option"]
        for choice_index, choice in enumerate(choices):
            exercise_choices.append({
                "exercise_id": row["id"],
                "choice": choice,
                "is_correct": choice_index == 0,
            })

    old_phrases = read_old("common_phrases.json")
    common_phrases = [
        {
            "id": row["id"],
            "phrase": row["phrase"],
            "meaning": row["usage_note"],
            "category_id": (row["lesson_id"] - 1) % len(categories) + 1,
            "audio_id": 400000 + row["id"],
        }
        for row in old_phrases
    ]

    old_drills = read_old("pronunciation_drills.json")
    pronunciation_drills = []
    pronunciation_phonemes = []
    for row in old_drills:
        pronunciation_drills.append({
            "id": row["id"],
            "lesson_id": row["lesson_id"],
            "text": row["phrase"],
            "stress": row["phonetic_hint"],
            "difficulty": ["A1", "A2", "B1", "B2"][row["id"] % 4],
        })
        for order, phoneme in enumerate(row["target_sound"].upper(), 1):
            pronunciation_phonemes.append({
                "drill_id": row["id"],
                "phoneme_order": order,
                "phoneme": phoneme,
            })

    flashcards = [
        {
            "id": row["id"],
            "lesson_id": row["lesson_id"],
            "front": row["front"],
            "back": row["back"],
            "type": row["card_type"],
        }
        for row in read_old("review_cards.json")
    ]

    roleplays = [
        {
            "id": 900000 + lesson["id"],
            "lesson_id": lesson["id"],
            "scenario": lesson["title"],
            "ai_role": "Tutor",
            "student_goal": lesson["objective"],
        }
        for lesson in lessons[:2000]
    ]
    speaking_scenarios = [
        {
            "id": 100000 + lesson["id"],
            "lesson_id": lesson["id"],
            "prompt": lesson["objective"],
            "sample_answer": "I can answer clearly and politely.",
        }
        for lesson in lessons[:2000]
    ]
    speaking_keywords = [
        {"scenario_id": row["id"], "keyword": keyword}
        for row in speaking_scenarios
        for keyword in row["prompt"].lower().replace(".", "").split()[:3]
    ]
    learning_paths = [
        {"id": 1, "title": "Travel English", "description": "Learn English for travel."},
        {"id": 2, "title": "Work English", "description": "Speak clearly at work."},
    ]
    learning_path_categories = [
        {"path_id": 1, "category_id": 2},
        {"path_id": 1, "category_id": 8},
        {"path_id": 2, "category_id": 3},
        {"path_id": 2, "category_id": 5},
    ]
    achievements = [
        {"id": 1, "title": "Practice Streak", "description": "Practice for several days in a row.", "icon": "streak"},
        {"id": 2, "title": "Pronunciation Starter", "description": "Finish your first drill.", "icon": "mic"},
    ]
    audio = [
        {"id": row["audio_id"], "path": f"audio/vocabulary/{row['word']}.mp3", "duration": 1.5, "speaker": "female_us", "accent": "American"}
        for row in vocabulary[:1000]
    ] + [
        {"id": row["audio_id"], "path": f"audio/phrases/{row['id']}.mp3", "duration": 1.8, "speaker": "male_uk", "accent": "British"}
        for row in common_phrases[:1000]
    ]
    tags = [{"id": index + 1, "name": row["slug"]} for index, row in enumerate(categories)]

    joins = {
        "lesson_vocabulary": [{"lesson_id": lesson["id"], "vocabulary_id": (lesson["id"] - 1) % len(vocabulary) + 1} for lesson in lessons],
        "lesson_grammar": [{"lesson_id": lesson["id"], "grammar_id": (lesson["id"] - 1) % len(grammar_patterns) + 1} for lesson in lessons],
        "lesson_phrases": [{"lesson_id": lesson["id"], "phrase_id": (lesson["id"] - 1) % len(common_phrases) + 1} for lesson in lessons],
        "lesson_dialogues": [{"lesson_id": row["lesson_id"], "dialogue_id": row["id"]} for row in dialogues],
        "lesson_exercises": [{"lesson_id": row["lesson_id"], "exercise_id": row["id"]} for row in exercises],
        "lesson_drills": [{"lesson_id": row["lesson_id"], "drill_id": row["id"]} for row in pronunciation_drills],
        "vocabulary_tags": [{"vocabulary_id": row["id"], "tag_id": (row["id"] - 1) % len(tags) + 1} for row in vocabulary],
    }

    files = {
        "categories.json": categories,
        "lessons.json": lessons,
        "dialogues.json": dialogues,
        "dialogue_turns.json": dialogue_turns,
        "vocabulary.json": vocabulary,
        "vocabulary_examples.json": vocabulary_examples,
        "grammar.json": grammar_patterns,
        "grammar_patterns.json": grammar_patterns,
        "exercises.json": exercises,
        "exercise_choices.json": exercise_choices,
        "flashcards.json": flashcards,
        "pronunciation.json": pronunciation_drills,
        "pronunciation_drills.json": pronunciation_drills,
        "pronunciation_phonemes.json": pronunciation_phonemes,
        "common_phrases.json": common_phrases,
        "roleplays.json": roleplays,
        "speaking.json": speaking_scenarios,
        "speaking_scenarios.json": speaking_scenarios,
        "speaking_keywords.json": speaking_keywords,
        "learning_paths.json": learning_paths,
        "learning_path_categories.json": learning_path_categories,
        "achievements.json": achievements,
        "audio.json": audio,
        "tags.json": tags,
        "metadata.json": {"version": "1.0.0", "locale": "en", "record_counts": {}},
    }
    for name, rows in joins.items():
        files[f"{name}.json"] = rows
    files["metadata.json"]["record_counts"] = {name: len(rows) if isinstance(rows, list) else 1 for name, rows in files.items()}

    for name, rows in files.items():
        write_source(name, rows)
    return files


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE categories (id INTEGER PRIMARY KEY, slug TEXT UNIQUE, title TEXT, description TEXT, icon TEXT, color TEXT, cefr TEXT);
CREATE TABLE lessons (id INTEGER PRIMARY KEY, category_id INTEGER, title TEXT, objective TEXT, difficulty TEXT, estimated_minutes INTEGER, order_index INTEGER);
CREATE TABLE dialogues (id INTEGER PRIMARY KEY, lesson_id INTEGER, type TEXT);
CREATE TABLE dialogue_turns (id INTEGER PRIMARY KEY, dialogue_id INTEGER, turn_number INTEGER, speaker TEXT, text TEXT);
CREATE TABLE vocabulary (id INTEGER PRIMARY KEY, word TEXT, meaning TEXT, phonetic TEXT, part_of_speech TEXT, cefr TEXT, audio_id INTEGER);
CREATE TABLE vocabulary_examples (id INTEGER PRIMARY KEY, vocabulary_id INTEGER, example TEXT);
CREATE TABLE grammar_patterns (id INTEGER PRIMARY KEY, title TEXT, rule TEXT, formula TEXT, cefr TEXT);
CREATE TABLE exercises (id INTEGER PRIMARY KEY, lesson_id INTEGER, type TEXT, question TEXT, hint TEXT, difficulty TEXT);
CREATE TABLE exercise_choices (exercise_id INTEGER, choice TEXT, is_correct INTEGER);
CREATE TABLE pronunciation_drills (id INTEGER PRIMARY KEY, lesson_id INTEGER, text TEXT, stress TEXT, difficulty TEXT);
CREATE TABLE pronunciation_phonemes (drill_id INTEGER, phoneme_order INTEGER, phoneme TEXT);
CREATE TABLE common_phrases (id INTEGER PRIMARY KEY, phrase TEXT, meaning TEXT, category_id INTEGER, audio_id INTEGER);
CREATE TABLE flashcards (id INTEGER PRIMARY KEY, lesson_id INTEGER, front TEXT, back TEXT, type TEXT);
CREATE TABLE speaking_scenarios (id INTEGER PRIMARY KEY, lesson_id INTEGER, prompt TEXT, sample_answer TEXT);
CREATE TABLE speaking_keywords (scenario_id INTEGER, keyword TEXT);
CREATE TABLE roleplays (id INTEGER PRIMARY KEY, lesson_id INTEGER, scenario TEXT, ai_role TEXT, student_goal TEXT);
CREATE TABLE achievements (id INTEGER PRIMARY KEY, title TEXT, description TEXT, icon TEXT);
CREATE TABLE learning_paths (id INTEGER PRIMARY KEY, title TEXT, description TEXT);
CREATE TABLE learning_path_categories (path_id INTEGER, category_id INTEGER);
CREATE TABLE audio (id INTEGER PRIMARY KEY, path TEXT, duration REAL, speaker TEXT, accent TEXT);
CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE lesson_vocabulary (lesson_id INTEGER, vocabulary_id INTEGER);
CREATE TABLE lesson_grammar (lesson_id INTEGER, grammar_id INTEGER);
CREATE TABLE lesson_phrases (lesson_id INTEGER, phrase_id INTEGER);
CREATE TABLE lesson_dialogues (lesson_id INTEGER, dialogue_id INTEGER);
CREATE TABLE lesson_exercises (lesson_id INTEGER, exercise_id INTEGER);
CREATE TABLE lesson_drills (lesson_id INTEGER, drill_id INTEGER);
CREATE TABLE vocabulary_tags (vocabulary_id INTEGER, tag_id INTEGER);
CREATE INDEX idx_lessons_category ON lessons(category_id);
CREATE INDEX idx_lessons_difficulty ON lessons(difficulty);
CREATE INDEX idx_dialogues_lesson ON dialogues(lesson_id);
CREATE INDEX idx_exercises_lesson ON exercises(lesson_id);
CREATE INDEX idx_vocab_word ON vocabulary(word);
"""


TABLE_FILES = {
    "categories": "categories.json",
    "lessons": "lessons.json",
    "dialogues": "dialogues.json",
    "dialogue_turns": "dialogue_turns.json",
    "vocabulary": "vocabulary.json",
    "vocabulary_examples": "vocabulary_examples.json",
    "grammar_patterns": "grammar_patterns.json",
    "exercises": "exercises.json",
    "exercise_choices": "exercise_choices.json",
    "pronunciation_drills": "pronunciation_drills.json",
    "pronunciation_phonemes": "pronunciation_phonemes.json",
    "common_phrases": "common_phrases.json",
    "flashcards": "flashcards.json",
    "speaking_scenarios": "speaking_scenarios.json",
    "speaking_keywords": "speaking_keywords.json",
    "roleplays": "roleplays.json",
    "achievements": "achievements.json",
    "learning_paths": "learning_paths.json",
    "learning_path_categories": "learning_path_categories.json",
    "audio": "audio.json",
    "tags": "tags.json",
    "lesson_vocabulary": "lesson_vocabulary.json",
    "lesson_grammar": "lesson_grammar.json",
    "lesson_phrases": "lesson_phrases.json",
    "lesson_dialogues": "lesson_dialogues.json",
    "lesson_exercises": "lesson_exercises.json",
    "lesson_drills": "lesson_drills.json",
    "vocabulary_tags": "vocabulary_tags.json",
}


def insert_rows(db, table, rows):
    if not rows:
        return
    table_columns = {
        row[1] for row in db.execute(f"PRAGMA table_info({table})").fetchall()
    }
    columns = [column for column in rows[0].keys() if column in table_columns]
    placeholders = ",".join(["?"] * len(columns))
    sql = f"INSERT INTO {table} ({','.join(columns)}) VALUES ({placeholders})"
    db.executemany(sql, [[int(value) if isinstance(value, bool) else value for value in (row.get(col) for col in columns)] for row in rows])


def build_database():
    OUT.mkdir(parents=True, exist_ok=True)
    db_path = OUT / "content.db"
    if db_path.exists():
        db_path.unlink()
    db = sqlite3.connect(db_path)
    db.executescript(SCHEMA)
    for table, file_name in TABLE_FILES.items():
        with (SRC / file_name).open(encoding="utf-8") as file:
            insert_rows(db, table, json.load(file))
    db.commit()
    db.close()
    digest = hashlib.sha256(db_path.read_bytes()).hexdigest()
    (OUT / "content.db.sha256").write_text(digest, encoding="utf-8")


def main():
    build_sources()
    build_database()


if __name__ == "__main__":
    main()
