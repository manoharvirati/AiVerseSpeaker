part of 'speak_flow_app.dart';

class CoachShell extends StatefulWidget {
  const CoachShell({super.key});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _index = 0;
  LessonSummary? _selectedPracticeLesson;

  void _openPractice([LessonSummary? lesson]) {
    setState(() {
      _selectedPracticeLesson = lesson;
      _index = 2;
    });
  }

  void _openAiSetup() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.72,
        maxChildSize: 0.96,
        builder: (context, scrollController) => AiSetupWizard(
          onReady: () {
            Navigator.of(context).maybePop();
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onStartSpeaking: _openPractice,
        onStartAiSetup: _openAiSetup,
        onOpenTopics: () => setState(() => _index = 1),
      ),
      ExploreScreen(onStartPractice: _openPractice),
      PracticeScreen(initialLesson: _selectedPracticeLesson),
      const ProgressScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      ),
      extendBody: true,
      bottomNavigationBar: SpeakFlowBottomNav(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}


