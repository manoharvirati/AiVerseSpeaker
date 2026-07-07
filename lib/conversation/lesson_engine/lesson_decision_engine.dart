class LessonDecision {
  const LessonDecision({
    required this.hasGrammarIssue,
    required this.correction,
    required this.followUpQuestion,
    required this.focusSkill,
  });

  final bool hasGrammarIssue;
  final String correction;
  final String followUpQuestion;
  final String focusSkill;
}

class LessonDecisionEngine {
  LessonDecision evaluate(String transcript) {
    final hasSequenceIssue = !transcript.toLowerCase().contains('then');

    return LessonDecision(
      hasGrammarIssue: hasSequenceIssue,
      correction: hasSequenceIssue
          ? 'Nice. A smoother version is: I went to the market with my friend, and then we tried a new cafe.'
          : 'Great sentence. Your sequence is clear.',
      followUpQuestion: 'What did you enjoy most about it?',
      focusSkill: hasSequenceIssue ? 'Grammar' : 'Fluency',
    );
  }
}
