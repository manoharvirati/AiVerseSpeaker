part of '../../app/speak_flow_app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onStartSpeaking,
    required this.onStartAiSetup,
    required this.onOpenTopics,
  });

  final ValueChanged<LessonSummary?> onStartSpeaking;
  final VoidCallback onStartAiSetup;
  final VoidCallback onOpenTopics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<HomeDashboardData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = DashboardRepository(LocalDatabase.instance).loadHome();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<HomeDashboardData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
            children: [
              SpeakFlowHomeHeader(data: data),
              const SizedBox(height: 18),
              HomeHeroCard(data: data),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: data.modelInstall?.status == ModelInstallStatus.loaded
                    ? () => widget.onStartSpeaking(data.recommendedLesson)
                    : widget.onStartAiSetup,
                icon: Icon(
                  data.modelInstall?.status == ModelInstallStatus.loaded
                      ? Icons.mic_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: const Text('Start AI Speaking'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppTheme.purple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              StatsStrip(data: data),
              const SizedBox(height: 18),
              ContinueLessonCard(
                lesson: data.recommendedLesson,
                modelInstall: data.modelInstall,
                onStartSpeaking: () => widget.onStartSpeaking(data.recommendedLesson),
              ),
              const SizedBox(height: 22),
              SectionTitle(
                title: 'Quick Start',
                action: TextButton(
                  onPressed: widget.onOpenTopics,
                  child: const Text('See All Topics'),
                ),
              ),
              const SizedBox(height: 12),
              QuickStartRail(
                lessons: data.lessons,
                onSelected: (lesson) => widget.onStartSpeaking(lesson),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 430;
                  if (narrow) {
                    return Column(
                      children: [
                        TodaysGoalCard(data: data),
                        const SizedBox(height: 14),
                        HomeSkillsCard(data: data),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: TodaysGoalCard(data: data)),
                      const SizedBox(width: 14),
                      Expanded(child: HomeSkillsCard(data: data)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              OfflineBenefitsCard(modelInstall: data.modelInstall),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.025, end: 0);
        },
      ),
    );
  }
}

class SpeakFlowHomeHeader extends StatelessWidget {
  const SpeakFlowHomeHeader({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final active = data.modelInstall?.status == ModelInstallStatus.loaded;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SettingsDetailSheet(
              title: 'Download Manager',
              value: data.modelInstall?.title ?? 'Model & Resources',
              modelInstall: data.modelInstall,
              memory: data.memory,
            ),
          ),
          icon: const Icon(Icons.menu_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning, Manohar!',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('Let\'s practice and become fluent today.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        OfflineBadge(
          label: active ? 'Offline Mode' : 'AI Setup',
          subtitle: active ? '100% Local AI' : 'Model needed',
          active: active,
        ),
      ],
    );
  }
}

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final artWidth = compact ? 96.0 : constraints.maxWidth * 0.34;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 22, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI TUTOR',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.violet,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Practice English\nAnytime, Anywhere',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All conversations, feedback and analysis happen on your device.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    const CompactPill(
                      icon: Icons.wifi_off_rounded,
                      label: 'No Internet Required',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: artWidth.clamp(86.0, 150.0),
                child: TutorIllustration(
                  label: 'Let\'s speak!',
                  color: colorFromHex(data.activeTutor?.colorHex ?? '7C3AED'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatsStrip extends StatelessWidget {
  const StatsStrip({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final todayMinutes = data.dailyActivity.isEmpty
        ? 0
        : data.dailyActivity
              .map((item) => item.practiceMinutes)
              .reduce((a, b) => a > b ? a : b);
    final topicsCompleted = data.lessons
        .where((lesson) => lesson.progress >= 1)
        .length;
    final bestScore = data.skillScores.isEmpty
        ? 0
        : data.skillScores
              .map((item) => item.score)
              .reduce((a, b) => a > b ? a : b);

    final pills = [
      StatPill(
        icon: Icons.track_changes_rounded,
        color: AppTheme.purple,
        value: '$todayMinutes',
        suffix: 'min',
        label: 'Today\'s Practice',
      ),
      StatPill(
        icon: Icons.local_fire_department_rounded,
        color: AppTheme.sky,
        value: '${data.streakDays}',
        label: 'Day Streak',
      ),
      StatPill(
        icon: Icons.trending_up_rounded,
        color: AppTheme.emerald,
        value: '$topicsCompleted',
        label: 'Topics Completed',
      ),
      StatPill(
        icon: Icons.star_rounded,
        color: AppTheme.orange,
        value: '$bestScore',
        label: 'Best Score',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 2 : 4;
        final spacing = constraints.maxWidth < 360 ? 10.0 : 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final pill in pills)
              SizedBox(width: width, child: pill),
          ],
        );
      },
    );
  }
}

class ContinueLessonCard extends StatelessWidget {
  const ContinueLessonCard({
    super.key,
    required this.lesson,
    required this.modelInstall,
    required this.onStartSpeaking,
  });

  final LessonSummary lesson;
  final ModelInstallRecord? modelInstall;
  final VoidCallback onStartSpeaking;

  @override
  Widget build(BuildContext context) {
    final progress = lesson.progress.clamp(0, 1);
    final modelLabel = modelInstall == null
        ? 'Download a model for full offline AI'
        : '${modelInstall!.title} model: ${modelInstall!.status.name}';
    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopicArt(
                category: lesson.category,
                title: lesson.title,
                size: compact ? 82 : 104,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Continue Learning',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lesson.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  modelLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.emerald,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppTheme.violet,
                  ),
                ),
              ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: compact ? 52 : 66,
                height: compact ? 52 : 66,
                child: FilledButton(
                  onPressed: onStartSpeaking,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    backgroundColor: AppTheme.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: Icon(Icons.play_arrow_rounded, size: compact ? 30 : 36),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PracticeGrid extends StatelessWidget {
  const PracticeGrid({super.key, required this.lessons});

  final List<LessonSummary> lessons;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: lessons.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.75,
      ),
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        return PracticeModeCard(
          mode: PracticeMode(
            lesson.title,
            iconForCategory(lesson.category),
            colorForCategory(lesson.category),
          ),
        );
      },
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final lesson = data.recommendedLesson;
    final mistake = data.memory.commonMistakes.isEmpty
        ? 'your speaking fluency'
        : data.memory.commonMistakes.first;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Recommendation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Practice ${lesson.title}. Your current focus is $mistake.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const IconButton.filled(
            onPressed: null,
            icon: Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}


