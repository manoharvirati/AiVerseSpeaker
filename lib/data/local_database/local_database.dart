import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';
import 'database_seed_data.dart';

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
    DatabaseSchema.createAll(batch);
    DatabaseSeedData.seedAll(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      DatabaseSchema.createTutorPersonasTable(batch);
      DatabaseSeedData.seedTutorPersonas(
        batch,
        DateTime.now().toIso8601String(),
      );
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
      DatabaseSchema.createProgressTables(batch);
      DatabaseSeedData.seedProgress(batch, DateTime.now().toIso8601String());
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
      DatabaseSchema.createSavedTopicsTable(batch);
      DatabaseSeedData.seedMissingLessons(
        batch,
        DateTime.now().toIso8601String(),
      );
      DatabaseSeedData.seedAppPreferences(
        batch,
        DateTime.now().toIso8601String(),
      );
      await batch.commit(noResult: true);
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
