class LocalInferenceEngine {
  Future<String> generateReply(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final userTranscript = _extract(prompt, 'User said:');
    final lessonGoal = _extract(prompt, 'Lesson goal:');
    final knownMistakes = _extract(prompt, 'Known mistakes:');
    final lower = userTranscript.toLowerCase();

    final opening = lower.length < 18
        ? 'Good start. Let\'s make it a little more complete.'
        : 'Nice answer. Your meaning is clear.';
    final topicHint = lessonGoal.isEmpty
        ? 'Add one specific detail so the listener can picture the situation.'
        : 'For this $lessonGoal practice, add one detail and keep your sentence natural.';
    final mistakeHint = knownMistakes.contains('past tense')
        ? 'Watch your past tense endings as you speak.'
        : 'Keep your word order simple and confident.';
    final followUp = _followUpFor(lessonGoal);

    return '$opening $topicHint $mistakeHint $followUp';
  }

  String _extract(String prompt, String label) {
    String? line;
    for (final item in prompt.split('\n')) {
      if (item.startsWith(label)) {
        line = item;
        break;
      }
    }
    if (line == null) return '';
    return line.substring(label.length).trim().replaceAll(RegExp(r'\.$'), '');
  }

  String _followUpFor(String lessonGoal) {
    final lower = lessonGoal.toLowerCase();
    if (lower.contains('coffee') || lower.contains('restaurant')) {
      return 'What size would you like, and would you like anything else?';
    }
    if (lower.contains('airport') || lower.contains('travel')) {
      return 'Can you ask one question about your gate or luggage?';
    }
    if (lower.contains('interview') || lower.contains('career')) {
      return 'Can you tell me one strength with a short example?';
    }
    if (lower.contains('hospital') || lower.contains('health')) {
      return 'Can you describe when the problem started?';
    }
    if (lower.contains('shopping')) {
      return 'Can you compare two options before you buy one?';
    }
    return 'Can you say one more sentence with a reason?';
  }
}
