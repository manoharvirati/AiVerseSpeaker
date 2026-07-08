part of '../../app/speak_flow_app.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<HomeDashboardData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = DashboardRepository(LocalDatabase.instance).loadHome();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<HomeDashboardData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
            children: [
              ProfileHeader(data: data),
              const SizedBox(height: 18),
              ProfileHeroCard(data: data),
              const SizedBox(height: 18),
              ProfileStatsCard(data: data),
              const SizedBox(height: 18),
              ProfileProgressCard(data: data),
              const SizedBox(height: 18),
              AchievementsStrip(achievements: data.achievements),
              const SizedBox(height: 18),
              ProfileSettingsCard(
                modelInstall: data.modelInstall,
                memory: data.memory,
              ),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.025, end: 0);
        },
      ),
    );
  }
}

class TutorSelector extends StatelessWidget {
  const TutorSelector({super.key, required this.tutors});

  final List<TutorPersonaSummary> tutors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Tutors', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final tutor = tutors[index];
                final color = colorFromHex(tutor.colorHex);
                return SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          TutorAvatar(name: tutor.name, size: 60, color: color),
                          if (tutor.active)
                            const Positioned(
                              right: -2,
                              bottom: -2,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.emerald,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tutor.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        tutor.specialty,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: tutors.length,
            ),
          ),
        ],
      ),
    );
  }
}

class ModelMappingCard extends StatelessWidget {
  const ModelMappingCard({super.key, required this.modelInstall});

  final ModelInstallRecord? modelInstall;

  @override
  Widget build(BuildContext context) {
    final options = ModelCatalog().allOptions();
    final activeModelId = modelInstall?.internalModelId;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Model Routing',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            modelInstall == null
                ? 'No model has been downloaded yet.'
                : 'Active: ${modelInstall!.title} (${modelInstall!.status.name})',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorForModelTier(
                        option.tier,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      iconForModelTier(option.tier),
                      color: colorForModelTier(option.tier),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          option.sourceLabel,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (activeModelId == option.internalModelId)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.emerald,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.memory});

  final LearnerMemory memory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Memory', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          InsightRow(text: 'Level: ${memory.level}'),
          InsightRow(text: 'Accent preference: ${memory.accentPreference}'),
          ...memory.commonMistakes.map(
            (mistake) => InsightRow(text: 'Common mistake: $mistake'),
          ),
          InsightRow(text: 'Daily goal: ${memory.dailyGoalMinutes} minutes'),
        ],
      ),
    );
  }
}

class GamificationCard extends StatelessWidget {
  const GamificationCard({super.key, required this.achievements});

  final List<AchievementSummary> achievements;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((item) => item.unlocked).toList();
    final locked = achievements.where((item) => !item.unlocked).toList();
    final current = unlocked.isEmpty ? null : unlocked.first;
    final next = locked.isEmpty ? null : locked.first;
    return GradientPanel(
      colors: const [AppTheme.emerald, Color(0xFF0EA5E9)],
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.title ?? 'New Speaker',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? 'All seeded achievements are unlocked.'
                      : '${next.xp} XP to unlock ${next.title}.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopicHeader extends StatelessWidget {
  const TopicHeader({super.key, required this.totalTopics, required this.completed});

  final int totalTopics;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Topics', style: Theme.of(context).textTheme.headlineMedium),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use the search field below to find topics.')),
          ),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use category and difficulty filters below.')),
          ),
          icon: const Icon(Icons.filter_alt_rounded),
        ),
      ],
    );
  }
}

class TopicHero extends StatelessWidget {
  const TopicHero({
    super.key,
    required this.categories,
    required this.topics,
    required this.completed,
  });

  final int categories;
  final int topics;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return GradientPanel(
      colors: const [AppTheme.purple, Color(0xFF312E81)],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$topics+ Real-Life Topics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Practice anytime, completely offline.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    HeroMetric(
                      icon: Icons.category_rounded,
                      value: '$categories',
                      label: 'Categories',
                    ),
                    HeroMetric(
                      icon: Icons.article_rounded,
                      value: '$topics',
                      label: 'Topics',
                    ),
                    HeroMetric(
                      icon: Icons.check_circle_rounded,
                      value: '$completed',
                      label: 'Completed',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const TutorIllustration(label: '...', color: AppTheme.violet),
        ],
      ),
    );
  }
}

class HeroMetric extends StatelessWidget {
  const HeroMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.emerald, size: 18),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryCarousel extends StatelessWidget {
  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.lessons,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final List<LessonSummary> lessons;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = categories[index];
          final count = lessons.where((lesson) => lesson.category == category).length;
          final color = colorForCategory(category);
          final selected = selectedCategory == category;
          return SizedBox(
            width: 98,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelected(category),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.18)
                      : AppTheme.card.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconForCategory(category), color: color, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      category,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count Topics',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: categories.length,
      ),
    );
  }
}

class DifficultyFilter extends StatelessWidget {
  const DifficultyFilter({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = ['All', 'Starter', 'Beginner', 'Intermediate', 'Advanced'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final active = selected == option;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(option),
              onSelected: (_) => onChanged(option),
              selectedColor: AppTheme.purple.withValues(alpha: 0.45),
              backgroundColor: AppTheme.card,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SpeakFlowSearchBar extends StatelessWidget {
  const SpeakFlowSearchBar({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppTheme.card.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PageHeading(
            title: 'Progress',
            subtitle: '${data.conversationCount} saved practice sessions',
          ),
        ),
        const OfflineBadge(label: 'Offline Mode', subtitle: 'Local analytics', active: true),
      ],
    );
  }
}

class WeeklyChartCard extends StatelessWidget {
  const WeeklyChartCard({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  Widget build(BuildContext context) {
    final bars = data.dailyActivity;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Practice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) return const SizedBox.shrink();
                        return Text(bars[index].dayLabel, style: Theme.of(context).textTheme.bodyMedium);
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(bars.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: bars[index].practiceMinutes.toDouble(),
                        width: 18,
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.sky]),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: math.max(10, bars.map((e) => e.practiceMinutes).fold(0, math.max).toDouble()),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementsStrip extends StatelessWidget {
  const AchievementsStrip({super.key, required this.achievements});

  final List<AchievementSummary> achievements;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Achievements',
            action: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.62,
                  minChildSize: 0.38,
                  maxChildSize: 0.86,
                  builder: (context, controller) => Container(
                    decoration: BoxDecoration(
                      color: AppTheme.sheetColor(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(18),
                      children: [
                        Text('Achievements', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 14),
                        ...achievements.map(
                          (achievement) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              child: ListTile(
                                leading: Icon(
                                  achievement.unlocked
                                      ? Icons.workspace_premium_rounded
                                      : Icons.lock_rounded,
                                  color: achievement.unlocked
                                      ? AppTheme.orange
                                      : AppTheme.muted,
                                ),
                                title: Text(achievement.title),
                                subtitle: Text('${achievement.xp} XP'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('View All'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return Container(
                  width: 104,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        achievement.unlocked ? Icons.workspace_premium_rounded : Icons.lock_rounded,
                        color: achievement.unlocked ? AppTheme.orange : AppTheme.muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: achievements.length,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final active = data.modelInstall?.status == ModelInstallStatus.loaded;
    return Row(
      children: [
        const Expanded(
          child: PageHeading(
            title: 'Profile',
            subtitle: 'Keep practicing, keep improving.',
          ),
        ),
        OfflineBadge(
          label: active ? 'Offline Mode' : 'AI Setup',
          subtitle: active ? '100% Local AI' : 'Model needed',
          active: active,
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SettingsDetailSheet(
              title: 'Language',
              value: data.memory.accentPreference,
              modelInstall: data.modelInstall,
              memory: data.memory,
            ),
          ),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }
}

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final xp = data.achievements
        .where((achievement) => achievement.unlocked)
        .fold<int>(0, (sum, item) => sum + item.xp);
    return GlassCard(
      child: Row(
        children: [
          const TutorAvatar(name: 'Manohar', size: 96, color: AppTheme.purple),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Manohar', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(width: 10),
                    Chip(label: Text(data.currentLevel.split(' ').first)),
                  ],
                ),
                Text('English Learner', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('${data.streakDays} Day Streak', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.orange)),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.star_rounded, color: AppTheme.violet, size: 42),
              const SizedBox(height: 6),
              Text('Level ${math.max(1, xp ~/ 300)}', style: Theme.of(context).textTheme.titleMedium),
              Text('$xp / 1200 XP', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final practiced = data.dailyActivity.fold<int>(0, (sum, item) => sum + item.practiceMinutes);
    final completed = data.lessons.where((lesson) => lesson.progress >= 1).length;
    final average = data.skillScores.isEmpty
        ? 0
        : (data.skillScores.fold<int>(0, (sum, item) => sum + item.score) /
                  data.skillScores.length)
              .round();
    final unlocked = data.achievements.where((achievement) => achievement.unlocked).length;
    final metrics = [
      ProfileMetric(
        icon: Icons.schedule_rounded,
        value: '${practiced}m',
        label: 'Time Practiced',
        color: AppTheme.emerald,
      ),
      ProfileMetric(
        icon: Icons.track_changes_rounded,
        value: '$completed',
        label: 'Topics Completed',
        color: AppTheme.sky,
      ),
      ProfileMetric(
        icon: Icons.trending_up_rounded,
        value: '$average%',
        label: 'Average Score',
        color: AppTheme.orange,
      ),
      ProfileMetric(
        icon: Icons.emoji_events_rounded,
        value: '$unlocked',
        label: 'Achievements',
        color: AppTheme.violet,
      ),
    ];

    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final columns = isNarrow ? 2 : 4;
          final spacing = isNarrow ? 10.0 : 8.0;
          final tileWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: 12,
            children: [
              for (final metric in metrics)
                SizedBox(width: tileWidth, child: metric),
            ],
          );
        },
      ),
    );
  }
}

class ProfileMetric extends StatelessWidget {
  const ProfileMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class ProfileProgressCard extends StatelessWidget {
  const ProfileProgressCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final average = data.skillScores.isEmpty
        ? 0
        : (data.skillScores.fold<int>(0, (sum, item) => sum + item.score) /
                  data.skillScores.length)
              .round();
    return GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (average / 100).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  color: AppTheme.violet,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text('$average%', style: Theme.of(context).textTheme.headlineMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.skillScores
                  .map(
                    (score) => SkillLine(
                      label: score.skill,
                      value: score.score,
                      color: colorForSkill(score.skill),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({
    super.key,
    required this.modelInstall,
    required this.memory,
  });

  final ModelInstallRecord? modelInstall;
  final LearnerMemory memory;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.history_rounded, 'Practice History', ''),
      (Icons.bookmark_rounded, 'Saved Topics', ''),
      (
        Icons.download_rounded,
        'Download Manager',
        modelInstall == null ? 'Model & Resources' : modelInstall!.title,
      ),
      (Icons.graphic_eq_rounded, 'AI Voice', 'Mano (Male)'),
      (Icons.language_rounded, 'Language', memory.accentPreference),
    ];
    return GlassCard(
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(row.$1, color: AppTheme.muted),
                const SizedBox(width: 14),
                Expanded(
              child: Text(row.$2, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (row.$3.isNotEmpty)
                  Flexible(
                    child: Text(
                      row.$3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SettingsDetailSheet(
                      title: row.$2,
                      value: row.$3,
                      modelInstall: modelInstall,
                      memory: memory,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppTheme.muted,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SettingsDetailSheet extends StatefulWidget {
  const SettingsDetailSheet({
    super.key,
    required this.title,
    required this.value,
    required this.modelInstall,
    required this.memory,
  });

  final String title;
  final String value;
  final ModelInstallRecord? modelInstall;
  final LearnerMemory memory;

  @override
  State<SettingsDetailSheet> createState() => _SettingsDetailSheetState();
}

class _SettingsDetailSheetState extends State<SettingsDetailSheet> {
  late final DashboardRepository _repository;
  late Future<List<LessonSummary>> _savedFuture;
  bool _notifications = true;
  double _speechSpeed = 0.46;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(LocalDatabase.instance);
    _savedFuture = _repository.loadLessons();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _repository.loadSettings();
    if (!mounted) return;
    setState(() {
      _notifications = settings['notifications'] != 'false';
      _speechSpeed = double.tryParse(settings['speech_speed'] ?? '') ?? 0.46;
      _themeMode = themeModeFromSetting(settings['theme_mode']);
    });
  }

  Future<void> _writeSetting(String key, String value) async {
    await LocalDatabase.instance.writeSetting(key, value);
    await _loadSettings();
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await appThemeController.setThemeMode(mode);
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.sheetColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (widget.title == 'Download Manager')
                _DownloadManagerContent(modelInstall: widget.modelInstall)
              else if (widget.title == 'Saved Topics')
                FutureBuilder<List<LessonSummary>>(
                  future: _savedFuture,
                  builder: (context, snapshot) {
                    final saved = (snapshot.data ?? [])
                        .where((lesson) => lesson.saved)
                        .toList();
                    if (saved.isEmpty) {
                      return const GlassCard(
                        child: Text('No saved topics yet. Bookmark topics from the Topics tab.'),
                      );
                    }
                    return Column(
                      children: saved
                          .map(
                            (lesson) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Icon(iconForCategory(lesson.category), color: colorForCategory(lesson.category)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(lesson.title)),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                )
              else
                _SettingsControls(
                  title: widget.title,
                  value: widget.value,
                  notifications: _notifications,
                  speechSpeed: _speechSpeed,
                  themeMode: _themeMode,
                  memory: widget.memory,
                  onNotificationsChanged: (value) => _writeSetting(
                    'notifications',
                    value.toString(),
                  ),
                  onSpeechSpeedChanged: (value) => _writeSetting(
                    'speech_speed',
                    value.toStringAsFixed(2),
                  ),
                  onThemeModeChanged: _setThemeMode,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadManagerContent extends StatelessWidget {
  const _DownloadManagerContent({required this.modelInstall});

  final ModelInstallRecord? modelInstall;

  @override
  Widget build(BuildContext context) {
    final options = ModelCatalog().allOptions();
    return Column(
      children: [
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, color: AppTheme.sky),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  modelInstall == null
                      ? 'No offline model installed.'
                      : '${modelInstall!.title} is ${modelInstall!.status.name}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(
                children: [
                  Icon(iconForModelTier(option.tier), color: colorForModelTier(option.tier)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.title, style: Theme.of(context).textTheme.titleMedium),
                        Text(option.sourceLabel, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Text('${option.downloadSizeGb.toStringAsFixed(1)} GB'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsControls extends StatelessWidget {
  const _SettingsControls({
    required this.title,
    required this.value,
    required this.notifications,
    required this.speechSpeed,
    required this.themeMode,
    required this.memory,
    required this.onNotificationsChanged,
    required this.onSpeechSpeedChanged,
    required this.onThemeModeChanged,
  });

  final String title;
  final String value;
  final bool notifications;
  final double speechSpeed;
  final ThemeMode themeMode;
  final LearnerMemory memory;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<double> onSpeechSpeedChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value.isEmpty ? title : value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          SwitchListTile(
            value: notifications,
            onChanged: onNotificationsChanged,
            title: const Text('Practice reminders'),
            subtitle: const Text('Daily offline practice notification'),
          ),
          Divider(color: AppTheme.borderColor(context)),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                (ThemeMode.system, Icons.phone_android_rounded),
                (ThemeMode.light, Icons.light_mode_rounded),
                (ThemeMode.dark, Icons.dark_mode_rounded),
              ])
                ChoiceChip(
                  avatar: Icon(option.$2, size: 18),
                  label: Text(themeModeLabel(option.$1)),
                  selected: themeMode == option.$1,
                  onSelected: (_) => onThemeModeChanged(option.$1),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppTheme.borderColor(context)),
          Text('Speech speed', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: speechSpeed.clamp(0.2, 0.8),
            min: 0.2,
            max: 0.8,
            divisions: 6,
            label: speechSpeed.toStringAsFixed(2),
            onChanged: onSpeechSpeedChanged,
          ),
          Divider(color: AppTheme.borderColor(context)),
          InsightRow(text: 'Language: ${memory.accentPreference}'),
          const InsightRow(text: 'Privacy: all learning data remains local in SQLite.'),
          InsightRow(text: 'Theme: ${themeModeLabel(themeMode)} mode.'),
        ],
      ),
    );
  }
}

class QuickStartRail extends StatelessWidget {
  const QuickStartRail({
    super.key,
    required this.lessons,
    required this.onSelected,
  });

  final List<LessonSummary> lessons;
  final ValueChanged<LessonSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final lesson = lessons[index % lessons.length];
          final color = colorForCategory(lesson.category);
          return SizedBox(
            width: 104,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onSelected(lesson),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconForCategory(lesson.category), color: color),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      lesson.category,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lessons.where((item) => item.category == lesson.category).length} Topics',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: math.max(lessons.length, 1),
      ),
    );
  }
}

class TodaysGoalCard extends StatelessWidget {
  const TodaysGoalCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final practiced = data.dailyActivity.isEmpty
        ? 0
        : data.dailyActivity
              .map((item) => item.practiceMinutes)
              .reduce((a, b) => a > b ? a : b);
    final goal = data.memory.dailyGoalMinutes;
    final progress = goal == 0 ? 0.0 : (practiced / goal).clamp(0.0, 1.0);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s Goal', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppTheme.sky,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$practiced',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text('min', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'of $goal min',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSkillsCard extends StatelessWidget {
  const HomeSkillsCard({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skills Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          ...data.skillScores.take(4).map(
                (score) => SkillLine(
                  label: score.skill,
                  value: score.score,
                  color: colorForSkill(score.skill),
                ),
              ),
        ],
      ),
    );
  }
}

class OfflineBenefitsCard extends StatelessWidget {
  const OfflineBenefitsCard({super.key, required this.modelInstall});

  final ModelInstallRecord? modelInstall;

  @override
  Widget build(BuildContext context) {
    final ready = modelInstall?.status == ModelInstallStatus.loaded;
    final items = [
      (Icons.lock_rounded, '100% Private', 'Your data stays on your device.'),
      (Icons.bolt_rounded, 'Fast & Reliable', 'No internet, no delays.'),
      (
        Icons.shield_rounded,
        ready ? 'Local AI Ready' : 'Model Pending',
        ready ? modelInstall!.title : 'Download a model to go fully offline.',
      ),
    ];
    return GlassCard(
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: AppTheme.emerald),
                      const SizedBox(height: 8),
                      Text(item.$2, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: dark ? 28 : 18,
            offset: Offset(0, dark ? 16 : 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({
    super.key,
    required this.label,
    required this.subtitle,
    required this.active,
  });

  final String label;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: active ? AppTheme.emerald : AppTheme.orange,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: active ? AppTheme.emerald : AppTheme.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CompactPill extends StatelessWidget {
  const CompactPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class TutorIllustration extends StatelessWidget {
  const TutorIllustration({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 14,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 104,
              height: 132,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.9), AppTheme.purple],
                ),
                borderRadius: BorderRadius.circular(42),
              ),
              child: const Icon(Icons.face_rounded, size: 68, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class TopicArt extends StatelessWidget {
  const TopicArt({
    super.key,
    required this.category,
    required this.title,
    this.size = 86,
  });

  final String category;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(category);
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.88), const Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              iconForCategory(category),
              size: size * 0.58,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Center(
            child: Icon(
              iconForCategory(category),
              color: Colors.white,
              size: size * 0.34,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillLine extends StatelessWidget {
  const SkillLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(iconForSkill(label), color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value/100', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class SpeakFlowBottomNav extends StatelessWidget {
  const SpeakFlowBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.grid_view_rounded, 'Topics'),
      (Icons.mic_rounded, 'Practice'),
      (Icons.bar_chart_rounded, 'Progress'),
      (Icons.person_rounded, 'Profile'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context, alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final selected = selectedIndex == index;
              final isMic = index == 2;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onSelected(index),
                  child: Transform.translate(
                    offset: Offset(0, isMic ? -18 : 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isMic ? 72 : 42,
                          height: isMic ? 72 : 42,
                          decoration: BoxDecoration(
                            shape: isMic ? BoxShape.circle : BoxShape.rectangle,
                            borderRadius: isMic ? null : BorderRadius.circular(16),
                            gradient: selected || isMic
                                ? const LinearGradient(
                                    colors: [AppTheme.purple, AppTheme.sky],
                                  )
                                : null,
                            color: selected || isMic
                                ? null
                                : Colors.white.withValues(alpha: 0.03),
                            boxShadow: isMic
                                ? [
                                    BoxShadow(
                                      color: AppTheme.purple.withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            items[index].$1,
                            color: selected || isMic ? Colors.white : AppTheme.muted,
                            size: isMic ? 34 : 24,
                          ),
                        ),
                        if (!isMic) ...[
                          const SizedBox(height: 4),
                          Text(
                            items[index].$2,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: selected ? AppTheme.violet : AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}


