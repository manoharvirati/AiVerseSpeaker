part of '../../app/speak_flow_app.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final Future<ProgressDashboardData> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = DashboardRepository(
      LocalDatabase.instance,
    ).loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<ProgressDashboardData>(
        future: _progressFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
            children: [
              ProgressHeader(data: data),
              const SizedBox(height: 18),
              ProgressOverview(data: data),
              const SizedBox(height: 18),
              WeeklyChartCard(data: data),
              const SizedBox(height: 18),
              WeeklyHeatMap(data: data),
              const SizedBox(height: 18),
              AchievementsStrip(achievements: data.achievements),
              const SizedBox(height: 18),
              WeakAreasCard(data: data),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.025, end: 0);
        },
      ),
    );
  }
}

class ProgressOverview extends StatelessWidget {
  const ProgressOverview({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  Widget build(BuildContext context) {
    final average = data.skillScores.isEmpty
        ? 0
        : (data.skillScores.fold<int>(0, (sum, item) => sum + item.score) /
                  data.skillScores.length)
              .round();
    final ring = SizedBox(
      width: 122,
      height: 122,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (average / 100).clamp(0.0, 1.0),
            strokeWidth: 11,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: AppTheme.emerald,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$average%',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Text('Overall', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
    final meters = Column(
      children: data.skillScores
          .map(
            (score) => SkillLine(
              label: score.skill,
              value: score.score,
              color: colorForSkill(score.skill),
            ),
          )
          .toList(),
    );

    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                ring,
                const SizedBox(height: 18),
                meters,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 18),
              Expanded(child: meters),
            ],
          );
        },
      ),
    );
  }
}

class WeeklyHeatMap extends StatelessWidget {
  const WeeklyHeatMap({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Practice Calendar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                data.dailyActivity.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 42,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: data.dailyActivity[index].practiceMinutes > 0
                                ? AppTheme.emerald.withValues(alpha: 0.26)
                                : Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: data.dailyActivity[index].practiceMinutes > 0
                                  ? AppTheme.emerald
                                  : Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Icon(
                            data.dailyActivity[index].practiceMinutes > 0
                                ? Icons.check_rounded
                                : Icons.circle,
                            color: data.dailyActivity[index].practiceMinutes > 0
                                ? AppTheme.emerald
                                : AppTheme.muted,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.dailyActivity[index].dayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeakAreasCard extends StatelessWidget {
  const WeakAreasCard({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coach Memory', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (data.mistakes.isEmpty)
            Text(
              'No mistakes recorded yet. Complete a practice turn to create coaching data.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...data.mistakes.map(
              (mistake) => InsightRow(
                text:
                    '${mistake.label}: ${mistake.improvementPercent}% improvement tracked.',
              ),
            ),
          if (data.vocabulary.isNotEmpty)
            InsightRow(
              text:
                  'Review ${data.vocabulary.last.topic.toLowerCase()} vocabulary next.',
            ),
        ],
      ),
    );
  }
}


