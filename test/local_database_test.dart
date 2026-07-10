import 'package:ai_verse_speaker/ai/model_loader/ai_model_loader.dart';
import 'package:ai_verse_speaker/ai/model_loader/model_catalog.dart';
import 'package:ai_verse_speaker/core/device/device_compatibility_service.dart';
import 'package:ai_verse_speaker/data/local_database/local_database.dart';
import 'package:ai_verse_speaker/data/repositories/conversation_repository.dart';
import 'package:ai_verse_speaker/data/repositories/dashboard_repository.dart';
import 'package:ai_verse_speaker/data/repositories/learner_repository.dart';
import 'package:ai_verse_speaker/data/repositories/model_install_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LocalDatabase.instance.resetForTesting();
  });

  test('seeds learner data and persists model setup snapshots', () async {
    final database = LocalDatabase.instance;
    final learnerRepository = LearnerRepository(database);
    final modelRepository = ModelInstallRepository(database);
    final dashboardRepository = DashboardRepository(database);
    final conversationRepository = ConversationRepository(database);

    final memory = await learnerRepository.loadMemory();
    expect(memory.level, 'Intermediate B1');
    expect(memory.commonMistakes, contains('past tense endings'));
    final initialProgress = await dashboardRepository.loadProgress();
    final initialLessons = await dashboardRepository.loadLessons();
    expect(initialProgress.scoreFor('Speaking'), 0);
    expect(initialLessons.length, greaterThanOrEqualTo(500));
    expect(initialLessons.first.title, 'Ordering Coffee');
    expect(initialLessons.first.progress, 0.85);
    expect(initialLessons.first.description, isNotEmpty);
    expect(initialLessons.first.saved, isFalse);
    expect(await database.readSetting('theme_mode'), 'system');
    final db = await database.database;
    final packRows = await db.query('lesson_packs');
    final categoryRows = await db.rawQuery('SELECT count(*) AS total FROM categories');
    final vocabularyRows = await db.rawQuery('SELECT count(*) AS total FROM vocabulary');
    final exerciseRows = await db.rawQuery('SELECT count(*) AS total FROM exercise_items');
    final stepRows = await db.query(
      'lesson_steps',
      where: 'lesson_id = ?',
      whereArgs: [initialLessons.first.id],
    );
    final dialogueMatches = await db.rawQuery(
      'SELECT rowid FROM dialogues_fts WHERE text LIKE ?',
      ['%cappuccino%'],
    );
    final lessonSearchRows = await db.rawQuery('SELECT count(*) AS total FROM lessons_fts');
    final reviewRows = await db.query(
      'review_cards',
      where: 'lesson_id = ?',
      whereArgs: [initialLessons.first.id],
    );
    expect(packRows.first['slug'], 'core-offline-english');
    expect(categoryRows.first['total'], greaterThanOrEqualTo(12));
    expect(vocabularyRows.first['total'], 10000);
    expect(exerciseRows.first['total'], 20000);
    expect(stepRows.length, greaterThanOrEqualTo(4));
    expect(dialogueMatches, isNotEmpty);
    expect(lessonSearchRows.first['total'], greaterThanOrEqualTo(500));
    expect(reviewRows.length, greaterThanOrEqualTo(3));
    expect(
      initialProgress.dailyActivity.every((day) => day.practiceMinutes == 0),
      isTrue,
    );

    final model = ModelCatalog().recommendedFor(
      const DeviceProfile(
        ramGb: 8,
        freeStorageGb: 42,
        cpuClass: PerformanceClass.good,
        osVersion: 'Test OS',
        supportsOfflineMode: true,
        supportsRealtimeConversation: true,
      ),
    );

    await modelRepository.saveSnapshot(
      option: model,
      snapshot: const ModelInstallSnapshot(
        status: ModelInstallStatus.loaded,
        progress: 1,
        message: 'AI Tutor Ready',
      ),
      isRealDownload: AiModelLoader.performsRealDownload,
    );

    final latest = await modelRepository.latest();
    expect(latest?.title, 'Fast');
    expect(latest?.status, ModelInstallStatus.loaded);
    expect(latest?.isRealDownload, isTrue);

    await dashboardRepository.toggleSavedLesson(initialLessons.first);
    final savedLessons = await dashboardRepository.loadLessons();
    expect(
      savedLessons.firstWhere((lesson) => lesson.id == initialLessons.first.id).saved,
      isTrue,
    );

    await conversationRepository.saveTurn(
      transcript: 'I practiced today.',
      tutorReply: 'Nice work.',
      focusSkill: 'Grammar',
    );
    final updatedProgress = await dashboardRepository.loadProgress();
    final updatedLessons = await dashboardRepository.loadLessons();
    expect(updatedProgress.scoreFor('Speaking'), 4);
    expect(updatedProgress.scoreFor('Grammar'), 4);
    expect(updatedLessons.first.progress, greaterThanOrEqualTo(0.85));
    expect(
      updatedProgress.dailyActivity.any((day) => day.practiceMinutes == 1),
      isTrue,
    );
  });
}
