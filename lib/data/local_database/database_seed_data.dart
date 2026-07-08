import 'dart:convert';

import 'package:sqflite/sqflite.dart';

typedef LessonSeedRow = (
  String title,
  String category,
  String description,
  String difficulty,
  int estimatedMinutes,
  double progress,
  int recommended,
);

class DatabaseSeedData {
  const DatabaseSeedData._();

  static void seedAll(Batch batch) {
    final now = DateTime.now().toIso8601String();
    seedLearnerMemory(batch, now);
    seedSetupStatus(batch, now);
    seedAppPreferences(batch, now);
    seedVocabulary(batch, now);
    seedGrammarMistakes(batch, now);
    seedLessons(batch, now);
    seedAchievements(batch, now);
    seedTutorPersonas(batch, now);
    seedProgress(batch, now);
  }

  static void seedLearnerMemory(Batch batch, String now) {
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
  }

  static void seedSetupStatus(Batch batch, String now) {
    batch.insert('app_settings', {
      'key': 'setup_completed',
      'value': 'false',
      'updated_at': now,
    });
  }

  static void seedAppPreferences(Batch batch, String now) {
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

  static void seedVocabulary(Batch batch, String now) {
    final rows = [
      ('departure', 'Airport', 0.72),
      ('reservation', 'Restaurant', 0.81),
      ('deadline', 'Business', 0.64),
    ];
    for (final row in rows) {
      batch.insert('vocabulary', {
        'word': row.$1,
        'topic': row.$2,
        'mastery': row.$3,
        'updated_at': now,
      });
    }
  }

  static void seedGrammarMistakes(Batch batch, String now) {
    final rows = [
      ('Past tense endings', 'I go to market yesterday.', 18),
      ('Sequence words', 'I ate lunch I went home.', 12),
      ('Article usage', 'I visited a airport.', 9),
    ];
    for (final row in rows) {
      batch.insert('grammar_mistakes', {
        'label': row.$1,
        'example': row.$2,
        'improvement_percent': row.$3,
        'updated_at': now,
      });
    }
  }

  static void seedLessons(Batch batch, String now) {
    for (final row in offlineLessonRows()) {
      _insertLesson(batch, row, now);
    }
  }

  static void seedMissingLessons(Batch batch, String now) {
    for (final row in offlineLessonRows(skipCoreRows: true)) {
      _insertLesson(
        batch,
        row,
        now,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static void _insertLesson(
    Batch batch,
    LessonSeedRow row,
    String now, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    batch.insert('lessons', {
      'title': row.$1,
      'category': row.$2,
      'description': row.$3,
      'difficulty': row.$4,
      'estimated_minutes': row.$5,
      'progress': row.$6,
      'recommended': row.$7,
      'updated_at': now,
    }, conflictAlgorithm: conflictAlgorithm);
  }

  static void seedAchievements(Batch batch, String now) {
    final rows = [
      ('Practice Streak', 450, 1),
      ('Storytelling Badge', 340, 0),
      ('Pronunciation Starter', 120, 1),
    ];
    for (final row in rows) {
      batch.insert('achievements', {
        'title': row.$1,
        'xp': row.$2,
        'unlocked': row.$3,
        'updated_at': now,
      });
    }
  }

  static void seedProgress(Batch batch, String now) {
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

  static void seedTutorPersonas(Batch batch, String now) {
    final rows = [
      ('Emma', 'Friendly', '2563EB', 1),
      ('David', 'Business English', '10B981', 0),
      ('Sophia', 'IELTS', '8B5CF6', 0),
      ('Alex', 'American Accent', 'F97316', 0),
      ('Mia', 'British Accent', '0EA5E9', 0),
    ];
    for (final row in rows) {
      batch.insert('tutor_personas', {
        'name': row.$1,
        'specialty': row.$2,
        'color_hex': row.$3,
        'active': row.$4,
        'updated_at': now,
      });
    }
  }

  static List<LessonSeedRow> offlineLessonRows({
    bool skipCoreRows = false,
  }) {
    final coreRows = <LessonSeedRow>[
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
    final rows = skipCoreRows ? <LessonSeedRow>[] : [...coreRows];
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
      final situation =
          situations[(index ~/ categories.length) % situations.length];
      final round = index ~/ (categories.length * situations.length) + 1;
      final difficulty = difficulties[index % difficulties.length];
      final minutes = 8 + (index % 7);
      rows.add((
        '$situation ${round == 1 ? '' : round}'.trim(),
        category,
        '${verbForCategory(category)} in a realistic ${category.toLowerCase()} situation.',
        difficulty,
        minutes,
        0.0,
        0,
      ));
      index++;
    }
    return rows;
  }

  static String verbForCategory(String category) {
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
}
