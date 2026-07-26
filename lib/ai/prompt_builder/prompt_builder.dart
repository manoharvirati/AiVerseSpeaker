import '../../core/logging/app_logger.dart';

class PromptBuilder {
  String buildTutorPrompt({
    required String learnerLevel,
    required String lessonGoal,
    required String userTranscript,
    required List<String> knownMistakes,
    required List<String> vocabulary,
    required List<String> dialogueLines,
    required List<String> exercisePrompts,
    required List<String> pronunciationPhrases,
    required String grammarFocus,
    List<({String tutor, String user})> recentTurns = const [],
  }) {
    AppLogger.ai(
      'Building prompt lesson="$lessonGoal" vocab=${vocabulary.length} dialogues=${dialogueLines.length} exercises=${exercisePrompts.length} memory=${recentTurns.length}',
    );
    return [
      buildSystemPrompt(),
      buildLessonContext(
        learnerLevel: learnerLevel,
        lessonGoal: lessonGoal,
        grammarFocus: grammarFocus,
        vocabulary: vocabulary,
        dialogueLines: dialogueLines,
        exercisePrompts: exercisePrompts,
        pronunciationPhrases: pronunciationPhrases,
      ),
      buildConversationContext(
        knownMistakes: knownMistakes,
        recentTurns: recentTurns,
      ),
      buildUserPrompt(userTranscript),
      buildTaskPrompt(),
    ].join('\n\n');
  }

  String buildSystemPrompt() {
    return '''
SYSTEM
You are AiVerse Speaker.
You are a friendly English speaking tutor.

Your goals:
- Help the learner speak English naturally.
- Correct mistakes gently.
- Keep conversations flowing.
- Never overwhelm beginners.

Rules:
- Maximum 2 short sentences.
- Ask exactly one follow-up question.
- Use simple English.
- Encourage the learner.''';
  }

  String buildLessonContext({
    required String learnerLevel,
    required String lessonGoal,
    required String grammarFocus,
    required List<String> vocabulary,
    required List<String> dialogueLines,
    required List<String> exercisePrompts,
    required List<String> pronunciationPhrases,
  }) {
    final limitedVocabulary = vocabulary.take(12).join('\n');
    final limitedDialogues = dialogueLines.take(6).join('\n');
    final limitedExercises = exercisePrompts.take(2).join('\n');
    final limitedPronunciation = pronunciationPhrases.take(2).join('\n');

    return '''
LESSON
Level: $learnerLevel
Lesson: $lessonGoal

GRAMMAR
${grammarFocus.isEmpty ? 'Use clear word order and natural phrases.' : grammarFocus}

VOCABULARY
${limitedVocabulary.isEmpty ? 'practice\nanswer\ndetail\nbecause' : limitedVocabulary}

DIALOGUE
${limitedDialogues.isEmpty ? 'Tutor: Hello! Let\'s practice.\nUser: I am ready.' : limitedDialogues}

EXERCISES
${limitedExercises.isEmpty ? 'Answer with one clear sentence.' : limitedExercises}

PRONUNCIATION
${limitedPronunciation.isEmpty ? 'Speak slowly and clearly.' : limitedPronunciation}''';
  }

  String buildConversationContext({
    required List<String> knownMistakes,
    required List<({String tutor, String user})> recentTurns,
  }) {
    final mistakes = knownMistakes.take(5).toList(growable: false);
    final memory = recentTurns.take(6).map((turn) {
      return 'User: ${turn.user}\nTutor: ${turn.tutor}';
    }).join('\n');

    return '''
SESSION
Known mistakes:
${mistakes.isEmpty ? '- None yet' : mistakes.map((mistake) => '- $mistake').join('\n')}

Previous conversation:
${memory.isEmpty ? 'No previous turns in this session.' : memory}''';
  }

  String buildUserPrompt(String userTranscript) {
    return '''
USER
User said:
"$userTranscript"''';
  }

  String buildTaskPrompt() {
    return '''
TASK
Continue the conversation.
If the user made a mistake, give one short correction.
Then ask one simple follow-up question.''';
  }
}
