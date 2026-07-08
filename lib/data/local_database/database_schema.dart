import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static void createAll(Batch batch) {
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE learner_memory (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        level TEXT NOT NULL,
        common_mistakes TEXT NOT NULL,
        vocabulary_mastered TEXT NOT NULL,
        accent_preference TEXT NOT NULL,
        daily_goal_minutes INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE model_installations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tier TEXT NOT NULL,
        title TEXT NOT NULL,
        internal_model_id TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL,
        is_real_download INTEGER NOT NULL,
        local_path TEXT,
        checksum TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE conversation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transcript TEXT NOT NULL,
        tutor_reply TEXT NOT NULL,
        focus_skill TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        topic TEXT NOT NULL,
        mastery REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE grammar_mistakes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        example TEXT NOT NULL,
        improvement_percent INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL DEFAULT 'Starter',
        estimated_minutes INTEGER NOT NULL DEFAULT 5,
        progress REAL NOT NULL,
        recommended INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        xp INTEGER NOT NULL,
        unlocked INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    createProgressTables(batch);
    createTutorPersonasTable(batch);
    createSavedTopicsTable(batch);
  }

  static void createProgressTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS skill_scores (
        skill TEXT PRIMARY KEY,
        score INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_activity (
        day_label TEXT PRIMARY KEY,
        practice_minutes INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static void createTutorPersonasTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS tutor_personas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialty TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        active INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static void createSavedTopicsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS saved_topics (
        lesson_id INTEGER PRIMARY KEY,
        saved_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');
  }
}
