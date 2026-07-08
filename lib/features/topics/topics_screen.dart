part of '../../app/speak_flow_app.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.onStartPractice});

  final ValueChanged<LessonSummary> onStartPractice;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final DashboardRepository _dashboardRepository;
  late Future<List<LessonSummary>> _lessonsFuture;
  String _query = '';
  String _difficulty = 'All';
  String? _category;

  @override
  void initState() {
    super.initState();
    _dashboardRepository = DashboardRepository(LocalDatabase.instance);
    _lessonsFuture = _dashboardRepository.loadLessons();
  }

  Future<void> _toggleSaved(LessonSummary lesson) async {
    await _dashboardRepository.toggleSavedLesson(lesson);
    if (!mounted) return;
    setState(() => _lessonsFuture = _dashboardRepository.loadLessons());
  }

  void _openTopic(LessonSummary lesson) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopicDetailSheet(
        lesson: lesson,
        onStartPractice: () {
          Navigator.of(context).pop();
          widget.onStartPractice(lesson);
        },
        onToggleSaved: () async {
          await _toggleSaved(lesson);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<List<LessonSummary>>(
        future: _lessonsFuture,
        builder: (context, snapshot) {
          final lessons = snapshot.data;
          if (lessons == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final filtered = lessons.where((lesson) {
            final matchesQuery =
                _query.isEmpty ||
                lesson.title.toLowerCase().contains(_query.toLowerCase()) ||
                lesson.category.toLowerCase().contains(_query.toLowerCase());
            final matchesDifficulty =
                _difficulty == 'All' || lesson.difficulty == _difficulty;
            final matchesCategory =
                _category == null || lesson.category == _category;
            return matchesQuery && matchesDifficulty && matchesCategory;
          }).toList();
          final completed = lessons.where((lesson) => lesson.progress >= 1).length;
          final categories = lessons.map((lesson) => lesson.category).toSet().toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
            children: [
              TopicHeader(
                totalTopics: lessons.length,
                completed: completed,
              ),
              const SizedBox(height: 18),
              TopicHero(
                categories: categories.length,
                topics: lessons.length,
                completed: completed,
              ),
              const SizedBox(height: 22),
              SectionTitle(
                title: 'Browse by Category',
                action: TextButton(
                  onPressed: () => setState(() => _category = null),
                  child: const Text('View All'),
                ),
              ),
              const SizedBox(height: 12),
              CategoryCarousel(
                categories: categories,
                lessons: lessons,
                selectedCategory: _category,
                onSelected: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: 18),
              DifficultyFilter(
                selected: _difficulty,
                onChanged: (value) => setState(() => _difficulty = value),
              ),
              const SizedBox(height: 14),
              SpeakFlowSearchBar(
                hint: 'Search topics...',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              ...filtered.map(
                (lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SpeakFlowLessonRow(
                    lesson: lesson,
                    onTap: () => _openTopic(lesson),
                    onToggleSaved: () => _toggleSaved(lesson),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.025, end: 0);
        },
      ),
    );
  }
}


