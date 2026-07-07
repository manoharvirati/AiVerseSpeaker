class PromptBuilder {
  String buildTutorPrompt({
    required String learnerLevel,
    required String lessonGoal,
    required String userTranscript,
    required List<String> knownMistakes,
  }) {
    return [
      'You are a warm English speaking tutor.',
      'Learner level: $learnerLevel.',
      'Lesson goal: $lessonGoal.',
      'Known mistakes: ${knownMistakes.join(", ")}.',
      'User said: $userTranscript',
      'Reply naturally, correct gently, and ask one follow-up question.',
    ].join('\n');
  }
}
