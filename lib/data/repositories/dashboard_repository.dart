import '../local_database/local_database.dart';
import 'learner_repository.dart';
import 'model_install_repository.dart';
import 'package:sqflite/sqflite.dart';

class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.progress,
    required this.recommended,
    required this.saved,
  });

  final int id;
  final String title;
  final String category;
  final String description;
  final String difficulty;
  final int estimatedMinutes;
  final double progress;
  final bool recommended;
  final bool saved;
}

class MistakeSummary {
  const MistakeSummary({
    required this.label,
    required this.example,
    required this.improvementPercent,
  });

  final String label;
  final String example;
  final int improvementPercent;
}

class AchievementSummary {
  const AchievementSummary({
    required this.title,
    required this.xp,
    required this.unlocked,
  });

  final String title;
  final int xp;
  final bool unlocked;
}

class TutorPersonaSummary {
  const TutorPersonaSummary({
    required this.name,
    required this.specialty,
    required this.colorHex,
    required this.active,
  });

  final String name;
  final String specialty;
  final String colorHex;
  final bool active;
}

class VocabularySummary {
  const VocabularySummary({
    required this.word,
    required this.topic,
    required this.mastery,
  });

  final String word;
  final String topic;
  final double mastery;
}

class SkillScoreSummary {
  const SkillScoreSummary({required this.skill, required this.score});

  final String skill;
  final int score;
}

class DailyActivitySummary {
  const DailyActivitySummary({
    required this.dayLabel,
    required this.practiceMinutes,
  });

  final String dayLabel;
  final int practiceMinutes;
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.memory,
    required this.lessons,
    required this.achievements,
    required this.tutors,
    required this.modelInstall,
    required this.streakDays,
    required this.currentLevel,
    required this.conversationCount,
    required this.skillScores,
    required this.dailyActivity,
  });

  final LearnerMemory memory;
  final List<LessonSummary> lessons;
  final List<AchievementSummary> achievements;
  final List<TutorPersonaSummary> tutors;
  final ModelInstallRecord? modelInstall;
  final int streakDays;
  final String currentLevel;
  final int conversationCount;
  final List<SkillScoreSummary> skillScores;
  final List<DailyActivitySummary> dailyActivity;

  LessonSummary get recommendedLesson {
    return lessons.firstWhere(
      (lesson) => lesson.recommended,
      orElse: () => lessons.first,
    );
  }

  TutorPersonaSummary? get activeTutor {
    for (final tutor in tutors) {
      if (tutor.active) return tutor;
    }
    return tutors.isEmpty ? null : tutors.first;
  }
}

class ProgressDashboardData {
  const ProgressDashboardData({
    required this.memory,
    required this.vocabulary,
    required this.mistakes,
    required this.achievements,
    required this.skillScores,
    required this.dailyActivity,
    required this.conversationCount,
  });

  final LearnerMemory memory;
  final List<VocabularySummary> vocabulary;
  final List<MistakeSummary> mistakes;
  final List<AchievementSummary> achievements;
  final List<SkillScoreSummary> skillScores;
  final List<DailyActivitySummary> dailyActivity;
  final int conversationCount;

  int scoreFor(String skill) {
    for (final item in skillScores) {
      if (item.skill.toLowerCase() == skill.toLowerCase()) return item.score;
    }
    return 0;
  }
}

class DashboardRepository {
  DashboardRepository(this.database)
    : _learnerRepository = LearnerRepository(database),
      _modelRepository = ModelInstallRepository(database);

  final LocalDatabase database;
  final LearnerRepository _learnerRepository;
  final ModelInstallRepository _modelRepository;

  Future<HomeDashboardData> loadHome() async {
    final progress = await loadProgress();
    return HomeDashboardData(
      memory: progress.memory,
      lessons: await loadLessons(),
      achievements: progress.achievements,
      tutors: await loadTutors(),
      modelInstall: await _modelRepository.latest(),
      streakDays: await _calculateStreakDays(),
      currentLevel: _levelFromProgress(progress),
      conversationCount: progress.conversationCount,
      skillScores: progress.skillScores,
      dailyActivity: progress.dailyActivity,
    );
  }

  Future<ProgressDashboardData> loadProgress() async {
    final db = await database.database;
    final conversationCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM conversation_history'),
        ) ??
        0;

    return ProgressDashboardData(
      memory: await _learnerRepository.loadMemory(),
      vocabulary: await loadVocabulary(),
      mistakes: await loadMistakes(),
      achievements: await loadAchievements(),
      skillScores: await loadSkillScores(),
      dailyActivity: await loadDailyActivity(),
      conversationCount: conversationCount,
    );
  }

  Future<int> _calculateStreakDays() async {
    final db = await database.database;
    final rows = await db.query(
      'conversation_history',
      columns: ['created_at'],
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return 0;

    final practiceDays = rows
        .map((row) => DateTime.tryParse(row['created_at'] as String))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    var streak = 0;
    while (practiceDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _levelFromProgress(ProgressDashboardData progress) {
    final average =
        (progress.scoreFor('Speaking') +
            progress.scoreFor('Grammar') +
            progress.scoreFor('Vocabulary')) /
        3;
    if (progress.conversationCount < 2) return 'Starter A1';
    if (average < 70) return 'Elementary A2';
    if (average < 84) return 'Intermediate B1';
    return 'Upper B2';
  }

  Future<List<LessonSummary>> loadLessons() async {
    final db = await database.database;
    final rows = await db.rawQuery('''
      SELECT lessons.*, saved_topics.lesson_id AS saved_lesson_id
      FROM lessons
      LEFT JOIN saved_topics ON saved_topics.lesson_id = lessons.id
      ORDER BY lessons.recommended DESC, lessons.progress DESC, lessons.id ASC
    ''');
    return rows
        .map(
          (row) => LessonSummary(
            id: row['id'] as int,
            title: row['title'] as String,
            category: row['category'] as String,
            description: row['description'] as String,
            difficulty: row['difficulty'] as String,
            estimatedMinutes: row['estimated_minutes'] as int,
            progress: row['progress'] as double,
            recommended: row['recommended'] == 1,
            saved: row['saved_lesson_id'] != null,
          ),
        )
        .toList();
  }

  Future<void> toggleSavedLesson(LessonSummary lesson) async {
    final db = await database.database;
    if (lesson.saved) {
      await db.delete(
        'saved_topics',
        where: 'lesson_id = ?',
        whereArgs: [lesson.id],
      );
      return;
    }
    await db.insert('saved_topics', {
      'lesson_id': lesson.id,
      'saved_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> loadSettings() async {
    final db = await database.database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<List<MistakeSummary>> loadMistakes() async {
    final db = await database.database;
    final rows = await db.query('grammar_mistakes', orderBy: 'id ASC');
    return rows
        .map(
          (row) => MistakeSummary(
            label: row['label'] as String,
            example: row['example'] as String,
            improvementPercent: row['improvement_percent'] as int,
          ),
        )
        .toList();
  }

  Future<List<VocabularySummary>> loadVocabulary() async {
    final db = await database.database;
    final rows = await db.query('vocabulary', orderBy: 'mastery DESC');
    return rows
        .map(
          (row) => VocabularySummary(
            word: row['word'] as String,
            topic: row['topic'] as String,
            mastery: row['mastery'] as double,
          ),
        )
        .toList();
  }

  Future<List<AchievementSummary>> loadAchievements() async {
    final db = await database.database;
    final rows = await db.query(
      'achievements',
      orderBy: 'unlocked DESC, id ASC',
    );
    return rows
        .map(
          (row) => AchievementSummary(
            title: row['title'] as String,
            xp: row['xp'] as int,
            unlocked: row['unlocked'] == 1,
          ),
        )
        .toList();
  }

  Future<List<SkillScoreSummary>> loadSkillScores() async {
    final db = await database.database;
    final rows = await db.query('skill_scores', orderBy: 'skill ASC');
    return rows
        .map(
          (row) => SkillScoreSummary(
            skill: row['skill'] as String,
            score: row['score'] as int,
          ),
        )
        .toList();
  }

  Future<List<DailyActivitySummary>> loadDailyActivity() async {
    final db = await database.database;
    final rows = await db.query('daily_activity');
    return rows
        .map(
          (row) => DailyActivitySummary(
            dayLabel: (row['day_label'] as String).replaceAll('2', ''),
            practiceMinutes: row['practice_minutes'] as int,
          ),
        )
        .toList();
  }

  Future<List<TutorPersonaSummary>> loadTutors() async {
    final db = await database.database;
    final rows = await db.query(
      'tutor_personas',
      orderBy: 'active DESC, id ASC',
    );
    return rows
        .map(
          (row) => TutorPersonaSummary(
            name: row['name'] as String,
            specialty: row['specialty'] as String,
            colorHex: row['color_hex'] as String,
            active: row['active'] == 1,
          ),
        )
        .toList();
  }
}
