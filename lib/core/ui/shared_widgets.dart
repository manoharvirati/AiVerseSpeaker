part of '../../app/speak_flow_app.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [AppTheme.navy, Color(0xFF0F1025), Color(0xFF060713)]
              : const [Color(0xFFF8FAFC), Color(0xFFEEF6FF), Color(0xFFFDFBFF)],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(child: child);
  }
}

class GradientPanel extends StatelessWidget {
  const GradientPanel({super.key, required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.suffix,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 6),
              FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    if (suffix != null) ...[
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          suffix!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
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
    );
  }
}

class PracticeMode {
  const PracticeMode(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}

class PracticeModeCard extends StatelessWidget {
  const PracticeModeCard({super.key, required this.mode});

  final PracticeMode mode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mode.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(mode.icon, color: mode.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class LessonRow extends StatelessWidget {
  const LessonRow({super.key, required this.lesson});

  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(lesson.category);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(iconForCategory(lesson.category), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${lesson.category} • ${lesson.difficulty} • ${lesson.estimatedMinutes}m',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: lesson.progress,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            onPressed: null,
            child: Text(lesson.progress == 0 ? 'Start' : 'Resume'),
          ),
        ],
      ),
    );
  }
}

class SpeakFlowLessonRow extends StatelessWidget {
  const SpeakFlowLessonRow({
    super.key,
    required this.lesson,
    required this.onTap,
    required this.onToggleSaved,
  });

  final LessonSummary lesson;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(lesson.category);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopicArt(category: lesson.category, title: lesson.title, size: 78),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: lesson.saved ? 'Saved topic' : 'Save topic',
                          onPressed: onToggleSaved,
                          icon: Icon(
                            lesson.saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color:
                                lesson.saved ? AppTheme.violet : AppTheme.muted,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppTheme.muted,
                      ),
                      Text(
                        '${lesson.estimatedMinutes}-${lesson.estimatedMinutes + 2} min',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 15,
                        color: AppTheme.muted,
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 118),
                        child: Text(
                          'AI Role: ${roleForCategory(lesson.category)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 88),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lesson.difficulty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${(lesson.progress * 100).round()}%',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                      SizedBox(
                        width: 34,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: lesson.progress.clamp(0, 1),
                            color: color,
                            backgroundColor:
                                AppTheme.surface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopicDetailSheet extends StatelessWidget {
  const TopicDetailSheet({
    super.key,
    required this.lesson,
    required this.onStartPractice,
    required this.onToggleSaved,
  });

  final LessonSummary lesson;
  final VoidCallback onStartPractice;
  final Future<void> Function() onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(lesson.category);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.sheetColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
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
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Topic Detail',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onToggleSaved,
                    icon: Icon(
                      lesson.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TopicArt(
                category: lesson.category,
                title: lesson.title,
                size: math.min(MediaQuery.sizeOf(context).width - 36, 360),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompactPill(icon: iconForCategory(lesson.category), label: lesson.category),
                    const SizedBox(height: 14),
                    Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 10),
                    Text(lesson.description, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        DetailChip(icon: Icons.signal_cellular_alt_rounded, label: lesson.difficulty, color: color),
                        DetailChip(icon: Icons.schedule_rounded, label: '${lesson.estimatedMinutes} min', color: AppTheme.sky),
                        DetailChip(icon: Icons.chat_rounded, label: roleForCategory(lesson.category), color: AppTheme.emerald),
                      ],
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
                    const SizedBox(height: 14),
                    ...learningGoalsFor(lesson).map((goal) => InsightRow(text: goal)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vocabulary & Grammar Focus', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vocabularyForCategory(lesson.category)
                          .map((word) => Chip(label: Text(word)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      grammarFocusForCategory(lesson.category),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onStartPractice,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Start Practice'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppTheme.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DetailChip extends StatelessWidget {
  const DetailChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> learningGoalsFor(LessonSummary lesson) {
  return [
    'Speak naturally with an AI ${roleForCategory(lesson.category).toLowerCase()}.',
    'Use polite requests and follow-up questions.',
    'Complete a ${lesson.estimatedMinutes} minute voice-first practice.',
  ];
}

List<String> vocabularyForCategory(String category) {
  return switch (category.toLowerCase()) {
    'restaurant' => ['menu', 'reservation', 'recommend', 'bill'],
    'travel' => ['boarding pass', 'luggage', 'gate', 'delay'],
    'work & career' || 'business' => ['deadline', 'experience', 'strengths', 'project'],
    'health' => ['symptom', 'appointment', 'medicine', 'advice'],
    'shopping' => ['discount', 'receipt', 'exchange', 'available'],
    _ => ['actually', 'usually', 'prefer', 'because'],
  };
}

String grammarFocusForCategory(String category) {
  return switch (category.toLowerCase()) {
    'restaurant' => 'Grammar focus: polite requests with can, could, and would like.',
    'travel' => 'Grammar focus: question forms and clarifying details.',
    'work & career' || 'business' => 'Grammar focus: concise past experience and future goals.',
    'health' => 'Grammar focus: describing symptoms with present perfect and simple present.',
    'shopping' => 'Grammar focus: comparisons, prices, and quantity expressions.',
    _ => 'Grammar focus: clear sentence order, transitions, and natural follow-ups.',
  };
}

class TutorAvatar extends StatelessWidget {
  const TutorAvatar({
    super.key,
    required this.name,
    required this.size,
    this.color = AppTheme.royalBlue,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, AppTheme.purple]),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Text(
          name.characters.first,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class AnimatedWaveform extends StatelessWidget {
  const AnimatedWaveform({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return SizedBox(
          height: 92,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(19, (index) {
              final wave = math.sin(
                animation.value * math.pi * 2 + index * 0.58,
              );
              final height = 18 + (wave.abs() * 58);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 7,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.45 + wave.abs() * 0.45,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class PracticeState {
  const PracticeState({
    required this.label,
    required this.prompt,
    required this.transcript,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final String label;
  final String prompt;
  final String transcript;
  final String helper;
  final IconData icon;
  final Color color;
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: AppTheme.royalBlue.withValues(alpha: 0.12),
            color: AppTheme.royalBlue,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '$score%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillMeter extends StatelessWidget {
  const SkillMeter({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class InsightRow extends StatelessWidget {
  const InsightRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.emerald,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

IconData iconForCategory(String category) {
  return switch (category.toLowerCase()) {
    'grammar' => Icons.edit_note_rounded,
    'travel' => Icons.flight_takeoff_rounded,
    'business' => Icons.handshake_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'pronunciation' => Icons.record_voice_over_rounded,
    _ => Icons.forum_rounded,
  };
}

Color colorForCategory(String category) {
  return switch (category.toLowerCase()) {
    'grammar' => AppTheme.purple,
    'travel' => AppTheme.royalBlue,
    'business' => const Color(0xFF6366F1),
    'restaurant' => AppTheme.orange,
    'pronunciation' => AppTheme.emerald,
    _ => const Color(0xFF0EA5E9),
  };
}

IconData iconForModelTier(ModelTier tier) {
  return switch (tier) {
    ModelTier.fast => Icons.bolt_rounded,
    ModelTier.balanced => Icons.tune_rounded,
    ModelTier.advanced => Icons.workspace_premium_rounded,
  };
}

Color colorForModelTier(ModelTier tier) {
  return switch (tier) {
    ModelTier.fast => AppTheme.emerald,
    ModelTier.balanced => AppTheme.royalBlue,
    ModelTier.advanced => AppTheme.purple,
  };
}

Color colorForSkill(String skill) {
  return switch (skill.toLowerCase()) {
    'speaking' => AppTheme.royalBlue,
    'grammar' => AppTheme.emerald,
    'vocabulary' => AppTheme.orange,
    'confidence' => AppTheme.purple,
    'fluency' => const Color(0xFF0EA5E9),
    _ => AppTheme.royalBlue,
  };
}

IconData iconForSkill(String skill) {
  return switch (skill.toLowerCase()) {
    'speaking' => Icons.mic_rounded,
    'grammar' => Icons.text_fields_rounded,
    'vocabulary' => Icons.menu_book_rounded,
    'confidence' => Icons.trending_up_rounded,
    'fluency' => Icons.graphic_eq_rounded,
    _ => Icons.insights_rounded,
  };
}

String roleForCategory(String category) {
  return switch (category.toLowerCase()) {
    'grammar' => 'Grammar Coach',
    'travel' => 'Airline Staff',
    'business' => 'Interviewer',
    'restaurant' => 'Barista',
    'pronunciation' => 'Accent Coach',
    _ => 'Conversation Partner',
  };
}

Color colorFromHex(String value) {
  final normalized = value.replaceAll('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppTheme.royalBlue : Color(parsed);
}


