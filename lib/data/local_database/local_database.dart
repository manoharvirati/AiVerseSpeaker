import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _opening;
    if (opening != null) return opening;

    _opening = _open();
    try {
      _database = await _opening;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ai_verse_speaker.db');
    return openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> resetForTesting() async {
    final existing = _database;
    if (existing != null) {
      await existing.close();
      _database = null;
    }
    _opening = null;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ai_verse_speaker.db');
    await deleteDatabase(path);
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

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

    _createProgressTables(batch);
    _createTutorPersonasTable(batch);
    _createSavedTopicsTable(batch);
    _seed(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      _createTutorPersonasTable(batch);
      _seedTutorPersonas(batch, DateTime.now().toIso8601String());
      await batch.commit(noResult: true);
    }
    if (oldVersion < 3) {
      await db.update(
        'achievements',
        {'title': 'Practice Streak'},
        where: 'title = ?',
        whereArgs: ['14 Day Streak'],
      );
    }
    if (oldVersion < 4) {
      final batch = db.batch();
      _createProgressTables(batch);
      _seedProgress(batch, DateTime.now().toIso8601String());
      await batch.commit(noResult: true);
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE lessons ADD COLUMN description TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE lessons ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'Starter'",
      );
      await db.execute(
        'ALTER TABLE lessons ADD COLUMN estimated_minutes INTEGER NOT NULL DEFAULT 5',
      );
      await db.update('lessons', {'progress': 0.0});
    }
    if (oldVersion < 6) {
      final batch = db.batch();
      _createSavedTopicsTable(batch);
      _seedMissingLessons(batch, DateTime.now().toIso8601String());
      _seedAppPreferences(batch, DateTime.now().toIso8601String());
      await batch.commit(noResult: true);
    }
  }

  void _createProgressTables(Batch batch) {
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

  void _createTutorPersonasTable(Batch batch) {
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

  void _createSavedTopicsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS saved_topics (
        lesson_id INTEGER PRIMARY KEY,
        saved_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )
    ''');
  }

  void _seed(Batch batch) {
    final now = DateTime.now().toIso8601String();
    batch.insert('learner_memory', {
      'id': 1,
      'level': 'Intermediate B1',
      'common_mistakes': jsonEncode(['past tense endings', 'sequence words']),
      'vocabulary_mastered': jsonEncode([
        'travel',
        'weekend plans',
        'daily routines',
      ]),
      'accent_preference': 'American English',
      'daily_goal_minutes': 15,
      'updated_at': now,
    });

    batch.insert('app_settings', {
      'key': 'setup_completed',
      'value': 'false',
      'updated_at': now,
    });
    _seedAppPreferences(batch, now);

    final vocabularyRows = [
      ('departure', 'Airport', 0.72),
      ('reservation', 'Restaurant', 0.81),
      ('deadline', 'Business', 0.64),
    ];
    for (final row in vocabularyRows) {
      batch.insert('vocabulary', {
        'word': row.$1,
        'topic': row.$2,
        'mastery': row.$3,
        'updated_at': now,
      });
    }

    final mistakeRows = [
      ('Past tense endings', 'I go to market yesterday.', 18),
      ('Sequence words', 'I ate lunch I went home.', 12),
      ('Article usage', 'I visited a airport.', 9),
    ];
    for (final row in mistakeRows) {
      batch.insert('grammar_mistakes', {
        'label': row.$1,
        'example': row.$2,
        'improvement_percent': row.$3,
        'updated_at': now,
      });
    }

    for (final row in _offlineLessonRows()) {
      batch.insert('lessons', {
        'title': row.$1,
        'category': row.$2,
        'description': row.$3,
        'difficulty': row.$4,
        'estimated_minutes': row.$5,
        'progress': row.$6,
        'recommended': row.$7,
        'updated_at': now,
      });
    }

    final achievementRows = [
      ('Practice Streak', 450, 1),
      ('Storytelling Badge', 340, 0),
      ('Pronunciation Starter', 120, 1),
    ];
    for (final row in achievementRows) {
      batch.insert('achievements', {
        'title': row.$1,
        'xp': row.$2,
        'unlocked': row.$3,
        'updated_at': now,
      });
    }

    _seedTutorPersonas(batch, now);
    _seedProgress(batch, now);
  }

  void _seedMissingLessons(Batch batch, String now) {
    for (final row in _offlineLessonRows(skipCoreRows: true)) {
      batch.insert('lessons', {
        'title': row.$1,
        'category': row.$2,
        'description': row.$3,
        'difficulty': row.$4,
        'estimated_minutes': row.$5,
        'progress': row.$6,
        'recommended': row.$7,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  void _seedAppPreferences(Batch batch, String now) {
    final settings = {
      'dark_mode': 'true',
      'language': 'English',
      'ai_voice': 'Mano (Male)',
      'speech_speed': '0.46',
      'notifications': 'true',
      'privacy_mode': 'local_only',
    };
    for (final entry in settings.entries) {
      batch.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  List<(String, String, String, String, int, double, int)> _offlineLessonRows({
    bool skipCoreRows = false,
  }) {
    final coreRows = <(String, String, String, String, int, double, int)>[
      (
        'Ordering Coffee',
        'Restaurant',
        'Order your favorite drink and ask about the menu.',
        'Beginner',
        8,
        0.85,
        1,
      ),
      (
        'At the Airport (Check-in)',
        'Travel',
        'Check in your luggage and ask travel related questions.',
        'Intermediate',
        10,
        0.60,
        0,
      ),
      (
        'Job Interview - Self Introduction',
        'Work & Career',
        'Introduce yourself and answer common interview questions.',
        'Advanced',
        12,
        0.40,
        0,
      ),
      (
        'Shopping at Supermarket',
        'Daily Life',
        'Ask for items, compare prices, and make a purchase.',
        'Beginner',
        8,
        1.0,
        0,
      ),
      (
        'At the Hospital',
        'Health',
        'Describe your problem and ask the doctor for advice.',
        'Intermediate',
        10,
        0.70,
        0,
      ),
    ];
    final rows = skipCoreRows
        ? <(String, String, String, String, int, double, int)>[]
        : [...coreRows];
    final categories = [
      'Daily Life',
      'Restaurant',
      'Travel',
      'Work & Career',
      'Education',
      'Family & Friends',
      'Health',
      'Shopping',
      'Business',
      'Pronunciation',
      'Culture',
      'Technology',
    ];
    final situations = [
      'Self Introduction',
      'Talking About Hobbies',
      'Daily Routine',
      'At Home',
      'Book a Hotel',
      'Ask for Directions',
      'Make an Appointment',
      'Return an Item',
      'Team Meeting',
      'Weekend Plans',
    ];
    final difficulties = ['Beginner', 'Intermediate', 'Advanced'];
    var index = 0;
    while (rows.length < 500) {
      final category = categories[index % categories.length];
      final situation = situations[(index ~/ categories.length) % situations.length];
      final round = index ~/ (categories.length * situations.length) + 1;
      final difficulty = difficulties[index % difficulties.length];
      final minutes = 8 + (index % 7);
      rows.add((
        '$situation ${round == 1 ? '' : round}'.trim(),
        category,
        '${_verbForCategory(category)} in a realistic ${category.toLowerCase()} situation.',
        difficulty,
        minutes,
        0.0,
        0,
      ));
      index++;
    }
    return rows;
  }

  String _verbForCategory(String category) {
    return switch (category) {
      'Restaurant' => 'Order food, ask questions, and respond politely',
      'Travel' => 'Solve travel problems and ask for useful information',
      'Work & Career' => 'Speak clearly in professional conversations',
      'Education' => 'Discuss classes, assignments, and study plans',
      'Family & Friends' => 'Share feelings, plans, and everyday stories',
      'Health' => 'Explain symptoms and understand advice',
      'Shopping' => 'Compare choices, prices, and preferences',
      'Business' => 'Negotiate, summarize, and present ideas',
      'Pronunciation' => 'Practice rhythm, stress, and clear sounds',
      _ => 'Practice natural everyday English',
    };
  }

  void _seedProgress(Batch batch, String now) {
    for (final skill in ['Speaking', 'Grammar', 'Vocabulary', 'Confidence']) {
      batch.insert('skill_scores', {
        'skill': skill,
        'score': 0,
        'updated_at': now,
      });
    }

    for (final day in ['M', 'T', 'W', 'T2', 'F', 'S', 'S2']) {
      batch.insert('daily_activity', {
        'day_label': day,
        'practice_minutes': 0,
        'updated_at': now,
      });
    }
  }

  void _seedTutorPersonas(Batch batch, String now) {
    final tutorRows = [
      ('Emma', 'Friendly', '2563EB', 1),
      ('David', 'Business English', '10B981', 0),
      ('Sophia', 'IELTS', '8B5CF6', 0),
      ('Alex', 'American Accent', 'F97316', 0),
      ('Mia', 'British Accent', '0EA5E9', 0),
    ];
    for (final row in tutorRows) {
      batch.insert('tutor_personas', {
        'name': row.$1,
        'specialty': row.$2,
        'color_hex': row.$3,
        'active': row.$4,
        'updated_at': now,
      });
    }
  }

  Future<String?> readSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> writeSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
