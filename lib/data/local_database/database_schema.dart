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
    createEnterpriseTables(batch);
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

  static void createEnterpriseTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY,
        slug TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        display_name TEXT NOT NULL,
        learner_level TEXT NOT NULL,
        preferred_language TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_packs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        version TEXT NOT NULL,
        locale TEXT NOT NULL,
        status TEXT NOT NULL,
        installed_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS content_pack_versions (
        pack_slug TEXT PRIMARY KEY,
        current_version TEXT NOT NULL,
        available_version TEXT,
        checksum TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_pack_items (
        lesson_id INTEGER NOT NULL,
        pack_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        PRIMARY KEY (lesson_id, pack_id),
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
        FOREIGN KEY (pack_id) REFERENCES lesson_packs(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        step_order INTEGER NOT NULL,
        step_type TEXT NOT NULL,
        title TEXT NOT NULL,
        prompt TEXT NOT NULL,
        expected_response TEXT,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_dialogues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        turn_order INTEGER NOT NULL,
        speaker TEXT NOT NULL,
        text TEXT NOT NULL,
        intent TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        example_type TEXT NOT NULL,
        text TEXT NOT NULL,
        translation TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_summaries (
        lesson_id INTEGER PRIMARY KEY,
        learning_goal TEXT NOT NULL,
        scenario TEXT NOT NULL,
        grammar_focus TEXT NOT NULL,
        tutor_opening_script TEXT NOT NULL,
        completion_summary TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS phrase_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER,
        phrase TEXT NOT NULL,
        formality TEXT NOT NULL,
        usage_note TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS exercise_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        exercise_type TEXT NOT NULL,
        prompt TEXT NOT NULL,
        answer TEXT NOT NULL,
        hint TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS pronunciation_drills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        phrase TEXT NOT NULL,
        phonetic_hint TEXT NOT NULL,
        target_sound TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS correction_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mistake_type TEXT NOT NULL,
        pattern TEXT NOT NULL,
        correction TEXT NOT NULL,
        explanation TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS review_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        card_type TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS review_schedule (
        card_id INTEGER PRIMARY KEY,
        due_at TEXT NOT NULL,
        interval_days INTEGER NOT NULL,
        ease_factor REAL NOT NULL,
        repetitions INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (card_id) REFERENCES review_cards(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS review_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        quality INTEGER NOT NULL,
        response TEXT NOT NULL DEFAULT '',
        attempted_at TEXT NOT NULL,
        FOREIGN KEY (card_id) REFERENCES review_cards(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS mastery_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        score REAL NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(entity_type, entity_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS lesson_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        score INTEGER,
        transcript_summary TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS mistake_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER,
        mistake_type TEXT NOT NULL,
        original_text TEXT NOT NULL,
        corrected_text TEXT NOT NULL,
        severity INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS download_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_type TEXT NOT NULL,
        asset_id TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL,
        local_path TEXT,
        error_message TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS model_assets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        tier TEXT NOT NULL,
        status TEXT NOT NULL,
        local_path TEXT,
        version TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        checksum TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS voice_assets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        locale TEXT NOT NULL,
        status TEXT NOT NULL,
        local_path TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    createSearchTables(batch);
  }

  static void createSearchTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS lessons_fts (
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS dialogues_fts (
        text TEXT NOT NULL,
        intent TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS vocabulary_fts (
        word TEXT NOT NULL,
        topic TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS exercise_fts (
        prompt TEXT NOT NULL,
        answer TEXT NOT NULL,
        hint TEXT NOT NULL
      )
    ''');
  }
}
