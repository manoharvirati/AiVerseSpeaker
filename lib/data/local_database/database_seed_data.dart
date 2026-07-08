import 'dart:convert';

import 'package:flutter/services.dart';
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

class OfflineContentBundle {
  const OfflineContentBundle({
    required this.categories,
    required this.lessons,
    required this.dialogues,
    required this.vocabulary,
    required this.reviewCards,
    required this.pronunciationDrills,
    required this.exercises,
    required this.commonPhrases,
    required this.grammarPatterns,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> lessons;
  final List<Map<String, dynamic>> dialogues;
  final List<Map<String, dynamic>> vocabulary;
  final List<Map<String, dynamic>> reviewCards;
  final List<Map<String, dynamic>> pronunciationDrills;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> commonPhrases;
  final List<Map<String, dynamic>> grammarPatterns;

  static Future<OfflineContentBundle> load() async {
    return OfflineContentBundle(
      categories: await _loadRows('assets/content/categories.json'),
      lessons: await _loadRows('assets/content/lessons.json'),
      dialogues: await _loadRows('assets/content/dialogues.json'),
      vocabulary: await _loadRows('assets/content/vocabulary.json'),
      reviewCards: await _loadRows('assets/content/review_cards.json'),
      pronunciationDrills: await _loadRows(
        'assets/content/pronunciation_drills.json',
      ),
      exercises: await _loadRows('assets/content/exercises.json'),
      commonPhrases: await _loadRows('assets/content/common_phrases.json'),
      grammarPatterns: await _loadRows('assets/content/grammar_patterns.json'),
    );
  }

  static Future<List<Map<String, dynamic>>> _loadRows(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
}

class DatabaseSeedData {
  const DatabaseSeedData._();

  static Future<void> seedAll(Batch batch) async {
    final now = DateTime.now().toIso8601String();
    final content = await OfflineContentBundle.load();
    seedLearnerMemory(batch, now);
    seedSetupStatus(batch, now);
    seedAppPreferences(batch, now);
    seedVocabulary(batch, now, content: content);
    seedGrammarMistakes(batch, now);
    seedLessons(batch, now, content: content);
    seedAchievements(batch, now);
    seedTutorPersonas(batch, now);
    seedProgress(batch, now);
    await seedEnterpriseContent(batch, now, content: content);
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
      'theme_mode': 'system',
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

  static void seedVocabulary(
    Batch batch,
    String now, {
    OfflineContentBundle? content,
  }) {
    if (content != null) {
      for (final row in content.vocabulary) {
        batch.insert('vocabulary', {
          'id': row['id'] as int,
          'word': row['word'] as String,
          'topic': row['topic'] as String,
          'mastery': (row['mastery'] as num).toDouble(),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return;
    }

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

  static void seedLessons(
    Batch batch,
    String now, {
    OfflineContentBundle? content,
  }) {
    if (content != null) {
      for (final row in content.lessons) {
        batch.insert('lessons', {
          'id': row['id'] as int,
          'title': row['title'] as String,
          'category': row['category'] as String,
          'description': row['description'] as String,
          'difficulty': row['difficulty'] as String,
          'estimated_minutes': row['estimated_minutes'] as int,
          'progress': (row['progress'] as num).toDouble(),
          'recommended': row['recommended'] as int,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return;
    }

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

  static Future<void> seedEnterpriseContent(
    Batch batch,
    String now, {
    OfflineContentBundle? content,
  }) async {
    final resolvedContent = content ?? await OfflineContentBundle.load();
    seedCategories(batch, now, resolvedContent);
    seedUser(batch, now);
    seedContentPack(batch, now);
    seedLessonDepth(batch, now, content: resolvedContent);
    seedOperationalState(batch, now);
    seedSearchIndexes(batch, content: resolvedContent);
  }

  static void seedCategories(
    Batch batch,
    String now,
    OfflineContentBundle content,
  ) {
    for (final row in content.categories) {
      batch.insert('categories', {
        'id': row['id'] as int,
        'slug': row['slug'] as String,
        'title': row['title'] as String,
        'description': row['description'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static void seedUser(Batch batch, String now) {
    batch.insert('users', {
      'id': 1,
      'display_name': 'Manohar',
      'learner_level': 'Intermediate B1',
      'preferred_language': 'English',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static void seedContentPack(Batch batch, String now) {
    batch.insert('lesson_packs', {
      'id': 1,
      'slug': 'core-offline-english',
      'title': 'Core Offline English',
      'description': 'Real-life speaking lessons, review cards, and drills.',
      'version': '1.0.0',
      'locale': 'en',
      'status': 'installed',
      'installed_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    batch.insert('content_pack_versions', {
      'pack_slug': 'core-offline-english',
      'current_version': '1.0.0',
      'available_version': null,
      'checksum': 'local-seed-v1',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (var lessonId = 1; lessonId <= 5; lessonId++) {
      batch.insert('lesson_pack_items', {
        'lesson_id': lessonId,
        'pack_id': 1,
        'sort_order': lessonId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static void seedLessonDepth(
    Batch batch,
    String now, {
    required OfflineContentBundle content,
  }) {
    final orderingCoffeeId = 1;
    batch.insert('lesson_summaries', {
      'lesson_id': orderingCoffeeId,
      'learning_goal': 'Order a drink politely and answer follow-up questions.',
      'scenario': 'You are in a coffee shop speaking with a barista.',
      'grammar_focus': 'Polite requests with would like and could I have.',
      'tutor_opening_script':
          'Hello! Welcome to our coffee shop. What would you like to order?',
      'completion_summary':
          'You practiced ordering, choosing a size, and confirming the order.',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final steps = [
      (
        1,
        'warmup',
        'Greeting',
        'Say hello and ask for the menu.',
        'Hello, could I see the menu please?',
      ),
      (
        2,
        'dialogue',
        'Order',
        'Order a cappuccino politely.',
        'I would like a cappuccino, please.',
      ),
      (
        3,
        'follow_up',
        'Size',
        'Choose a size and confirm hot or iced.',
        'A medium hot cappuccino, please.',
      ),
      (
        4,
        'review',
        'Summary',
        'Repeat the full order in one sentence.',
        'I would like a medium hot cappuccino to go, please.',
      ),
    ];
    for (final step in steps) {
      batch.insert('lesson_steps', {
        'lesson_id': orderingCoffeeId,
        'step_order': step.$1,
        'step_type': step.$2,
        'title': step.$3,
        'prompt': step.$4,
        'expected_response': step.$5,
        'metadata_json': jsonEncode({'skill': 'speaking'}),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final turn in content.dialogues) {
      batch.insert('lesson_dialogues', {
        'id': turn['id'] as int,
        'lesson_id': turn['lesson_id'] as int,
        'turn_order': turn['turn_order'] as int,
        'speaker': turn['speaker'] as String,
        'text': turn['text'] as String,
        'intent': turn['intent'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final examples = [
      ('polite_request', 'Could I have a cappuccino, please?', null),
      ('confirmation', 'That is all, thank you.', null),
      ('clarification', 'Sorry, could you repeat that?', null),
    ];
    for (final example in examples) {
      batch.insert('lesson_examples', {
        'lesson_id': orderingCoffeeId,
        'example_type': example.$1,
        'text': example.$2,
        'translation': example.$3,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final phrase in content.commonPhrases) {
      batch.insert('phrase_variants', {
        'id': phrase['id'] as int,
        'lesson_id': phrase['lesson_id'] as int,
        'phrase': phrase['phrase'] as String,
        'formality': phrase['formality'] as String,
        'usage_note': phrase['usage_note'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final exercise in content.exercises) {
      batch.insert('exercise_items', {
        'id': exercise['id'] as int,
        'lesson_id': exercise['lesson_id'] as int,
        'exercise_type': exercise['exercise_type'] as String,
        'prompt': exercise['prompt'] as String,
        'answer': exercise['answer'] as String,
        'hint': exercise['hint'] as String,
        'difficulty': exercise['difficulty'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final drill in content.pronunciationDrills) {
      batch.insert('pronunciation_drills', {
        'id': drill['id'] as int,
        'lesson_id': drill['lesson_id'] as int,
        'phrase': drill['phrase'] as String,
        'phonetic_hint': drill['phonetic_hint'] as String,
        'target_sound': drill['target_sound'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final correction in content.grammarPatterns) {
      batch.insert('correction_templates', {
        'id': correction['id'] as int,
        'mistake_type': correction['mistake_type'] as String,
        'pattern': correction['pattern'] as String,
        'correction': correction['correction'] as String,
        'explanation': correction['explanation'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final card in content.reviewCards) {
      final cardId = card['id'] as int;
      batch.insert('review_cards', {
        'id': cardId,
        'lesson_id': card['lesson_id'] as int,
        'front': card['front'] as String,
        'back': card['back'] as String,
        'card_type': card['card_type'] as String,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.insert('review_schedule', {
        'card_id': cardId,
        'due_at': now,
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 0,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    batch.insert('mastery_scores', {
      'entity_type': 'lesson',
      'entity_id': orderingCoffeeId,
      'score': 0.85,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static void seedOperationalState(Batch batch, String now) {
    batch.insert('model_assets', {
      'id': 'gemma-3-1b-fast',
      'title': 'AiVerse Speaker Fast',
      'tier': 'fast',
      'status': 'available',
      'local_path': null,
      'version': '1.0',
      'size_bytes': 0,
      'checksum': null,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('voice_assets', {
      'id': 'mano-male-en',
      'name': 'Mano (Male)',
      'locale': 'en',
      'status': 'system',
      'local_path': null,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('sync_state', {
      'key': 'mode',
      'value': 'offline_first',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static void seedSearchIndexes(
    Batch batch, {
    required OfflineContentBundle content,
  }) {
    for (final row in content.lessons) {
      batch.insert('lessons_fts', {
        'rowid': row['id'] as int,
        'title': row['title'] as String,
        'category': row['category'] as String,
        'description': row['description'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final row in content.dialogues) {
      batch.insert('dialogues_fts', {
        'rowid': row['id'] as int,
        'text': row['text'] as String,
        'intent': row['intent'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final row in content.vocabulary) {
      batch.insert('vocabulary_fts', {
        'rowid': row['id'] as int,
        'word': row['word'] as String,
        'topic': row['topic'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final row in content.exercises) {
      batch.insert('exercise_fts', {
        'rowid': row['id'] as int,
        'prompt': row['prompt'] as String,
        'answer': row['answer'] as String,
        'hint': row['hint'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
