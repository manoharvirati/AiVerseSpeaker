import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local_database/local_database.dart';

class LearnerMemory {
  const LearnerMemory({
    required this.level,
    required this.commonMistakes,
    required this.vocabularyMastered,
    required this.accentPreference,
    required this.dailyGoalMinutes,
  });

  final String level;
  final List<String> commonMistakes;
  final List<String> vocabularyMastered;
  final String accentPreference;
  final int dailyGoalMinutes;
}

class LearnerRepository {
  LearnerRepository(this.database);

  final LocalDatabase database;

  Future<LearnerMemory> loadMemory() async {
    final db = await database.database;
    final rows = await db.query('learner_memory', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      return const LearnerMemory(
        level: 'Intermediate B1',
        commonMistakes: ['past tense endings', 'sequence words'],
        vocabularyMastered: ['travel', 'weekend plans', 'daily routines'],
        accentPreference: 'American English',
        dailyGoalMinutes: 15,
      );
    }

    final row = rows.first;
    return LearnerMemory(
      level: row['level'] as String,
      commonMistakes: List<String>.from(
        jsonDecode(row['common_mistakes'] as String) as List,
      ),
      vocabularyMastered: List<String>.from(
        jsonDecode(row['vocabulary_mastered'] as String) as List,
      ),
      accentPreference: row['accent_preference'] as String,
      dailyGoalMinutes: row['daily_goal_minutes'] as int,
    );
  }

  Future<void> saveMemory(LearnerMemory memory) async {
    final db = await database.database;
    await db.insert('learner_memory', {
      'id': 1,
      'level': memory.level,
      'common_mistakes': jsonEncode(memory.commonMistakes),
      'vocabulary_mastered': jsonEncode(memory.vocabularyMastered),
      'accent_preference': memory.accentPreference,
      'daily_goal_minutes': memory.dailyGoalMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
