import '../local_database/local_database.dart';

class ConversationRepository {
  ConversationRepository(this.database);

  final LocalDatabase database;

  Future<void> saveTurn({
    required String transcript,
    required String tutorReply,
    required String focusSkill,
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      final nowText = now.toIso8601String();
      await txn.insert('conversation_history', {
        'transcript': transcript,
        'tutor_reply': tutorReply,
        'focus_skill': focusSkill,
        'created_at': nowText,
      });

      for (final skill in ['Speaking', focusSkill, 'Confidence']) {
        await txn.rawUpdate(
          '''
          UPDATE skill_scores
          SET score = CASE WHEN score + 4 > 100 THEN 100 ELSE score + 4 END,
              updated_at = ?
          WHERE lower(skill) = lower(?)
          ''',
          [nowText, skill],
        );
      }

      final dayLabel = _dayLabel(now);
      await txn.rawUpdate(
        '''
        UPDATE daily_activity
        SET practice_minutes = practice_minutes + 1,
            updated_at = ?
        WHERE day_label = ?
        ''',
        [nowText, dayLabel],
      );

      await txn.rawUpdate(
        '''
        UPDATE lessons
        SET progress = CASE WHEN progress + 0.05 > 1 THEN 1 ELSE progress + 0.05 END,
            updated_at = ?
        WHERE recommended = 1
        ''',
        [nowText],
      );
    });
  }

  String _dayLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'M',
      DateTime.tuesday => 'T',
      DateTime.wednesday => 'W',
      DateTime.thursday => 'T2',
      DateTime.friday => 'F',
      DateTime.saturday => 'S',
      DateTime.sunday => 'S2',
      _ => 'M',
    };
  }
}
