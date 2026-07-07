import '../../ai/inference/local_inference_engine.dart';
import '../../ai/prompt_builder/prompt_builder.dart';
import '../lesson_engine/lesson_decision_engine.dart';
import '../turn_manager/turn_manager.dart';

enum ConversationState {
  idle,
  listening,
  understanding,
  thinking,
  speaking,
  interrupted,
}

class ConversationSnapshot {
  const ConversationSnapshot({
    required this.state,
    required this.transcript,
    required this.tutorReply,
    required this.feedback,
  });

  final ConversationState state;
  final String transcript;
  final String tutorReply;
  final LessonDecision feedback;
}

class ConversationManager {
  ConversationManager({
    required this.turnManager,
    required this.lessonDecisionEngine,
    required this.promptBuilder,
    required this.inferenceEngine,
  });

  final TurnManager turnManager;
  final LessonDecisionEngine lessonDecisionEngine;
  final PromptBuilder promptBuilder;
  final LocalInferenceEngine inferenceEngine;

  ConversationState state = ConversationState.idle;

  Future<ConversationSnapshot> handleUserTranscript(
    String transcript, {
    String learnerLevel = 'Intermediate B1',
    String lessonGoal = 'general speaking',
    List<String> knownMistakes = const [],
  }) async {
    state = ConversationState.understanding;
    final decision = lessonDecisionEngine.evaluate(transcript);
    state = ConversationState.thinking;
    final prompt = promptBuilder.buildTutorPrompt(
      learnerLevel: learnerLevel,
      lessonGoal: lessonGoal,
      userTranscript: transcript,
      knownMistakes: knownMistakes,
    );
    final reply = await inferenceEngine.generateReply(prompt);
    state = ConversationState.speaking;
    final tutorReply = decision.hasGrammarIssue
        ? '${decision.correction} $reply'
        : reply;

    return ConversationSnapshot(
      state: state,
      transcript: transcript,
      tutorReply: tutorReply,
      feedback: decision,
    );
  }

  void interruptTutor() {
    state = ConversationState.interrupted;
    turnManager.markInterrupted();
    state = ConversationState.listening;
  }
}
