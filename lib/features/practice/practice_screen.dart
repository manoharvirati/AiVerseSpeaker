part of '../../app/speak_flow_app.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.initialLesson});

  final LessonSummary? initialLesson;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ConversationManager _conversationManager;
  late final ConversationRepository _conversationRepository;
  late final Future<HomeDashboardData> _practiceDataFuture;
  late final StreamingTextToSpeech _textToSpeech;
  late final StreamingSpeechRecognizer _speechRecognizer;
  StreamSubscription<String>? _speechSubscription;
  StreamSubscription<String>? _listenSubscription;
  ConversationSnapshot? _conversationSnapshot;
  String _spokenSubtitle = '';
  String _liveTranscript = '';
  bool _isTutorSpeaking = false;
  bool _isListening = false;
  bool _sessionStarted = false;
  bool _sessionComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _conversationManager = ConversationManager(
      turnManager: TurnManager(),
      lessonDecisionEngine: LessonDecisionEngine(),
      promptBuilder: PromptBuilder(),
      inferenceEngine: LocalInferenceEngine(),
    );
    _conversationRepository = ConversationRepository(LocalDatabase.instance);
    _practiceDataFuture = DashboardRepository(
      LocalDatabase.instance,
    ).loadHome();
    _textToSpeech = StreamingTextToSpeech();
    _speechRecognizer = StreamingSpeechRecognizer();
  }

  @override
  void dispose() {
    _speechSubscription?.cancel();
    _listenSubscription?.cancel();
    unawaited(_textToSpeech.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<HomeDashboardData>(
        future: _practiceDataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final lesson = widget.initialLesson ?? data.recommendedLesson;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
            children: [
              PracticeTopBar(lesson: lesson),
              const SizedBox(height: 18),
              if (_sessionComplete)
                PracticeResultCard(
                  snapshot: _conversationSnapshot,
                  lesson: lesson,
                  onPracticeAgain: _resetPractice,
                )
              else if (_sessionStarted)
                ConversationSessionView(
                  lesson: lesson,
                  snapshot: _conversationSnapshot,
                  liveTranscript: _liveTranscript,
                  spokenSubtitle: _spokenSubtitle,
                  isListening: _isListening,
                  isTutorSpeaking: _isTutorSpeaking,
                  animation: _controller,
                  onTapToSpeak: () => _runPracticeTurn(lesson, data),
                  onEndSession: _finishSession,
                )
              else
                PracticePrepView(
                  lesson: lesson,
                  onStart: () => _runPracticeTurn(lesson, data),
                ),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.025, end: 0);
        },
      ),
    );
  }

  Future<void> _runPracticeTurn(
    LessonSummary lesson,
    HomeDashboardData data,
  ) async {
    await _listenSubscription?.cancel();
    await _speechSubscription?.cancel();
    await _textToSpeech.stop();
    if (!mounted) return;
    setState(() {
      _sessionStarted = true;
      _sessionComplete = false;
      _isListening = true;
      _isTutorSpeaking = false;
      _liveTranscript = '';
      _spokenSubtitle = '';
    });

    String latestTranscript = '';
    _listenSubscription = _speechRecognizer.listen().listen(
      (transcript) {
        latestTranscript = transcript;
        if (!mounted) return;
        setState(() => _liveTranscript = transcript);
      },
      onDone: () async {
        final transcript = latestTranscript.isEmpty
            ? 'I would like a cappuccino, please.'
            : latestTranscript;
        final snapshot = await _conversationManager.handleUserTranscript(
          transcript,
          learnerLevel: data.currentLevel,
          lessonGoal: lesson.title,
          knownMistakes: data.memory.commonMistakes,
        );
        if (!mounted) return;
        await _conversationRepository.saveTurn(
          transcript: snapshot.transcript,
          tutorReply: snapshot.tutorReply,
          focusSkill: snapshot.feedback.focusSkill,
        );
        setState(() {
          _isListening = false;
          _conversationSnapshot = snapshot;
        });
        unawaited(_speakTutorReply(snapshot.tutorReply));
      },
    );
  }

  Future<void> _finishSession() async {
    await _listenSubscription?.cancel();
    await _speechSubscription?.cancel();
    await _textToSpeech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isTutorSpeaking = false;
      _sessionComplete = true;
    });
  }

  Future<void> _resetPractice() async {
    await _listenSubscription?.cancel();
    await _speechSubscription?.cancel();
    await _textToSpeech.stop();
    if (!mounted) return;
    setState(() {
      _conversationSnapshot = null;
      _spokenSubtitle = '';
      _liveTranscript = '';
      _isTutorSpeaking = false;
      _isListening = false;
      _sessionStarted = false;
      _sessionComplete = false;
    });
  }

  Future<void> _speakTutorReply(String reply) async {
    await _speechSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _spokenSubtitle = '';
      _isTutorSpeaking = true;
    });

    final words = <String>[];
    _speechSubscription = _textToSpeech.speak(reply).listen(
      (word) {
        if (!mounted) return;
        words.add(word);
        setState(() => _spokenSubtitle = words.join(' '));
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isTutorSpeaking = false);
      },
    );
  }
}

class PracticeTopBar extends StatelessWidget {
  const PracticeTopBar({super.key, required this.lesson});

  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text('Practice', style: Theme.of(context).textTheme.titleMedium),
              Text(
                lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => GlassCard(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Practice Tips', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      const InsightRow(text: 'Speak naturally. Short pauses are okay.'),
                      const InsightRow(text: 'Use the topic vocabulary before ending the session.'),
                      const InsightRow(text: 'Tap the mic again to answer the AI follow-up.'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class PracticePrepView extends StatelessWidget {
  const PracticePrepView({super.key, required this.lesson, required this.onStart});

  final LessonSummary lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopicArt(
          category: lesson.category,
          title: lesson.title,
          size: math.min(MediaQuery.sizeOf(context).width - 32, 420),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompactPill(icon: iconForCategory(lesson.category), label: lesson.category),
              const SizedBox(height: 14),
              Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(lesson.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: vocabularyForCategory(lesson.category)
                    .map((word) => Chip(label: Text(word)))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What you\'ll practice', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...learningGoalsFor(lesson).map((goal) => InsightRow(text: goal)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Start Speaking'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: AppTheme.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class ConversationSessionView extends StatelessWidget {
  const ConversationSessionView({
    super.key,
    required this.lesson,
    required this.snapshot,
    required this.liveTranscript,
    required this.spokenSubtitle,
    required this.isListening,
    required this.isTutorSpeaking,
    required this.animation,
    required this.onTapToSpeak,
    required this.onEndSession,
  });

  final LessonSummary lesson;
  final ConversationSnapshot? snapshot;
  final String liveTranscript;
  final String spokenSubtitle;
  final bool isListening;
  final bool isTutorSpeaking;
  final Animation<double> animation;
  final VoidCallback onTapToSpeak;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context) {
    final currentTranscript = liveTranscript.isEmpty
        ? 'Tap the microphone and answer naturally.'
        : liveTranscript;
    return Column(
      children: [
        ChatBubble(
          isUser: false,
          text:
              'Hello! Welcome to your ${lesson.title.toLowerCase()} practice. What would you like to say first?',
          active: snapshot == null && !isListening,
        ),
        if (liveTranscript.isNotEmpty) ...[
          const SizedBox(height: 12),
          ChatBubble(isUser: true, text: currentTranscript, active: isListening),
        ],
        if (snapshot != null) ...[
          const SizedBox(height: 12),
          ChatBubble(
            isUser: false,
            text: spokenSubtitle.isEmpty ? snapshot!.tutorReply : spokenSubtitle,
            active: isTutorSpeaking,
          ),
        ],
        const SizedBox(height: 22),
        AnimatedMicButton(
          animation: animation,
          listening: isListening,
          speaking: isTutorSpeaking,
          onTap: onTapToSpeak,
        ),
        const SizedBox(height: 10),
        Text(
          isListening
              ? 'Listening...'
              : isTutorSpeaking
              ? 'AI speaking...'
              : 'Tap to speak',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        LiveFeedbackPanel(snapshot: snapshot, lesson: lesson),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onEndSession,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: const Color(0xFF7F1D1D),
            foregroundColor: Colors.white,
          ),
          child: const Text('End Session'),
        ),
      ],
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.isUser,
    required this.text,
    required this.active,
  });

  final bool isUser;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) const TutorAvatar(name: 'AI', size: 36, color: AppTheme.sky),
        if (!isUser) const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(colors: [AppTheme.purple, AppTheme.royalBlue])
                  : null,
              color: isUser ? null : AppTheme.card.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active
                    ? AppTheme.emerald.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        if (isUser) const SizedBox(width: 10),
        if (isUser) const TutorAvatar(name: 'M', size: 36, color: AppTheme.purple),
      ],
    );
  }
}

class AnimatedMicButton extends StatelessWidget {
  const AnimatedMicButton({
    super.key,
    required this.animation,
    required this.listening,
    required this.speaking,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool listening;
  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = listening || speaking
            ? 1 + math.sin(animation.value * math.pi * 2).abs() * 0.08
            : 1.0;
        return Transform.scale(
          scale: pulse,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.sky]),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.purple.withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 54),
            ),
          ),
        );
      },
    );
  }
}

class LiveFeedbackPanel extends StatelessWidget {
  const LiveFeedbackPanel({super.key, required this.snapshot, required this.lesson});

  final ConversationSnapshot? snapshot;
  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final hasTurn = snapshot != null;
    final grammar = hasTurn && snapshot!.feedback.hasGrammarIssue ? 78 : hasTurn ? 90 : 0;
    final pronunciation = hasTurn ? 84 : 0;
    final fluency = hasTurn ? 80 : 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasTurn ? 'You\'re doing great!' : 'Live feedback appears here.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: MetricTile(label: 'Pronunciation', value: '$pronunciation%', color: AppTheme.emerald)),
              Expanded(child: MetricTile(label: 'Grammar', value: '$grammar%', color: AppTheme.sky)),
              Expanded(child: MetricTile(label: 'Fluency', value: '$fluency%', color: AppTheme.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class PracticeResultCard extends StatelessWidget {
  const PracticeResultCard({
    super.key,
    required this.snapshot,
    required this.lesson,
    required this.onPracticeAgain,
  });

  final ConversationSnapshot? snapshot;
  final LessonSummary lesson;
  final VoidCallback onPracticeAgain;

  @override
  Widget build(BuildContext context) {
    final hasGrammarIssue = snapshot?.feedback.hasGrammarIssue ?? false;
    final score = snapshot == null ? 0 : hasGrammarIssue ? 86 : 94;
    return Column(
      children: [
        Text('Great Job!', style: Theme.of(context).textTheme.headlineMedium),
        Text('You completed the session', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 22),
        GlassCard(
          child: Column(
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 14,
                      color: AppTheme.emerald,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$score', style: Theme.of(context).textTheme.displaySmall),
                          Text('Overall Score', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ResultFeedbackTabs(snapshot: snapshot, lesson: lesson),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onPracticeAgain,
                child: const Text('Practice Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onPracticeAgain,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.purple),
                child: const Text('Next Topic'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ResultFeedbackTabs extends StatelessWidget {
  const ResultFeedbackTabs({
    super.key,
    required this.snapshot,
    required this.lesson,
  });

  final ConversationSnapshot? snapshot;
  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final hasGrammarIssue = snapshot?.feedback.hasGrammarIssue ?? false;
    final grammar = snapshot == null ? 0 : hasGrammarIssue ? 78 : 90;
    final pronunciation = snapshot == null ? 0 : 84;
    final fluency = snapshot == null ? 0 : 82;
    final vocabulary = snapshot == null ? 0 : 82;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TabBar(
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Mistakes'),
                Tab(text: 'Transcript'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 360,
            child: TabBarView(
              children: [
                Column(
                  children: [
                    SkillLine(label: 'Pronunciation', value: pronunciation, color: AppTheme.emerald),
                    SkillLine(label: 'Grammar', value: grammar, color: AppTheme.sky),
                    SkillLine(label: 'Fluency', value: fluency, color: AppTheme.orange),
                    SkillLine(label: 'Vocabulary', value: vocabulary, color: AppTheme.violet),
                    const SizedBox(height: 14),
                    const InsightRow(text: 'Good use of polite expressions.'),
                    const InsightRow(text: 'Clear pronunciation of key words.'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detailed Feedback', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FeedbackDetailRow(
                      title: 'Pronunciation',
                      score: pronunciation,
                      text: 'Focus on the underlined words and keep a natural rhythm.',
                      color: AppTheme.emerald,
                    ),
                    FeedbackDetailRow(
                      title: 'Grammar',
                      score: grammar,
                      text: snapshot?.feedback.correction ?? 'Complete a turn to get grammar feedback.',
                      color: AppTheme.sky,
                    ),
                    FeedbackDetailRow(
                      title: 'Fluency',
                      score: fluency,
                      text: 'Try to reduce long pauses between sentences.',
                      color: AppTheme.orange,
                    ),
                  ],
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Topic: ${lesson.title}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text('You said:', style: Theme.of(context).textTheme.labelLarge),
                      Text(snapshot?.transcript ?? 'No transcript yet.'),
                      const SizedBox(height: 14),
                      Text('AI replied:', style: Theme.of(context).textTheme.labelLarge),
                      Text(snapshot?.tutorReply ?? 'No AI reply yet.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackDetailRow extends StatelessWidget {
  const FeedbackDetailRow({
    super.key,
    required this.title,
    required this.score,
    required this.text,
    required this.color,
  });

  final String title;
  final int score;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(iconForSkill(title), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                    Text('$score', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpokenSubtitleCard extends StatelessWidget {
  const SpokenSubtitleCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.volume_up_rounded, color: AppTheme.emerald),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class RuntimeDecisionCard extends StatelessWidget {
  const RuntimeDecisionCard({super.key, required this.snapshot});

  final ConversationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation Engine',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'State: ${snapshot.state.name.toUpperCase()}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            snapshot.tutorReply,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Next: ${snapshot.feedback.followUpQuestion}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.snapshot, required this.lesson});

  final ConversationSnapshot? snapshot;
  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final feedback = snapshot?.feedback;
    final score = feedback == null
        ? 0
        : feedback.hasGrammarIssue
        ? 78
        : 92;
    final grammar = feedback == null
        ? 0.0
        : feedback.hasGrammarIssue
        ? 0.68
        : 0.92;
    final fluency = snapshot == null ? 0.0 : 0.82;
    final vocabulary = snapshot == null
        ? lesson.progress
        : (0.72 + lesson.progress / 5);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot == null
                          ? 'No turn analyzed yet'
                          : 'Feedback ready',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      snapshot == null
                          ? 'Start a practice turn to generate a score.'
                          : 'Score for ${lesson.title}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ScoreRing(score: score),
            ],
          ),
          const SizedBox(height: 18),
          SkillMeter(
            label: 'Grammar',
            value: grammar,
            color: AppTheme.royalBlue,
          ),
          SkillMeter(label: 'Fluency', value: fluency, color: AppTheme.purple),
          SkillMeter(
            label: 'Vocabulary',
            value: vocabulary.clamp(0, 1).toDouble(),
            color: AppTheme.orange,
          ),
          const SizedBox(height: 18),
          if (snapshot == null)
            Text(
              'The next turn will be saved to conversation history and update Progress.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            CorrectionBlock(snapshot: snapshot!),
        ],
      ),
    );
  }
}

class CorrectionBlock extends StatelessWidget {
  const CorrectionBlock({super.key, required this.snapshot});

  final ConversationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Better version',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.feedback.correction,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Focus skill: ${snapshot.feedback.focusSkill}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}


