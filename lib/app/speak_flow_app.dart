import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ai/model_loader/ai_model_loader.dart';
import '../ai/model_loader/model_catalog.dart';
import '../ai/inference/local_inference_engine.dart';
import '../ai/prompt_builder/prompt_builder.dart';
import '../conversation/conversation_manager/conversation_manager.dart';
import '../conversation/lesson_engine/lesson_decision_engine.dart';
import '../conversation/turn_manager/turn_manager.dart';
import '../core/device/device_compatibility_service.dart';
import '../core/permissions/app_permission_service.dart';
import '../data/local_database/local_database.dart';
import '../data/repositories/conversation_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/learner_repository.dart';
import '../data/repositories/model_install_repository.dart';
import '../data/repositories/setup_repository.dart';
import '../speech/speech_recognition/streaming_speech_recognizer.dart';
import '../speech/text_to_speech/streaming_text_to_speech.dart';

part 'coach_shell.dart';
part '../core/ui/app_theme.dart';
part '../core/ui/shared_widgets.dart';
part '../features/home/home_screen.dart';
part '../features/practice/practice_screen.dart';
part '../features/progress/progress_screen.dart';
part '../features/topics/topics_screen.dart';
part '../features/profile/profile_screen.dart';

final appThemeController = AppThemeController(LocalDatabase.instance);

class EnglishCoachApp extends StatefulWidget {
  const EnglishCoachApp({super.key});

  @override
  State<EnglishCoachApp> createState() => _EnglishCoachAppState();
}

class _EnglishCoachAppState extends State<EnglishCoachApp> {
  @override
  void initState() {
    super.initState();
    unawaited(appThemeController.load());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'AiVerse Speaker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const AppLaunchFlow(),
        );
      },
    );
  }
}

class AppThemeController {
  AppThemeController(this._database);

  final LocalDatabase _database;
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> load() async {
    final value = await _database.readSetting('theme_mode');
    themeMode.value = themeModeFromSetting(value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _database.writeSetting('theme_mode', themeModeToSetting(mode));
  }
}

ThemeMode themeModeFromSetting(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String themeModeToSetting(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

String themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

enum LaunchStep {
  welcome,
  signIn,
  chooseLevel,
  chooseGoal,
  ready,
}

class AppLaunchFlow extends StatefulWidget {
  const AppLaunchFlow({super.key});

  @override
  State<AppLaunchFlow> createState() => _AppLaunchFlowState();
}

class _AppLaunchFlowState extends State<AppLaunchFlow> {
  final _database = LocalDatabase.instance;

  LaunchStep _step = LaunchStep.welcome;
  String _selectedLevel = 'Intermediate B1';
  String _selectedGoal = 'Speaking Practice';

  late final SetupRepository _setupRepository;
  late final LearnerRepository _learnerRepository;

  @override
  void initState() {
    super.initState();
    _setupRepository = SetupRepository(_database);
    _learnerRepository = LearnerRepository(_database);
    _restoreSetupState();
  }

  Future<void> _restoreSetupState() async {
    final isCompleted = await _setupRepository.isSetupCompleted();
    if (!mounted || !isCompleted) return;
    setState(() => _step = LaunchStep.ready);
  }

  void _continueFromWelcome() {
    setState(() => _step = LaunchStep.signIn);
  }

  Future<void> _continueAsGuest() async {
    await _database.writeSetting('auth_mode', 'guest');
    if (!mounted) return;
    setState(() => _step = LaunchStep.chooseLevel);
  }

  void _chooseLevel(String level) {
    setState(() => _selectedLevel = level);
  }

  void _continueFromLevel() {
    setState(() => _step = LaunchStep.chooseGoal);
  }

  void _chooseGoal(String goal) {
    setState(() => _selectedGoal = goal);
  }

  Future<void> _finishLightweightSetup() async {
    final currentMemory = await _learnerRepository.loadMemory();
    await _learnerRepository.saveMemory(
      LearnerMemory(
        level: _selectedLevel,
        commonMistakes: currentMemory.commonMistakes,
        vocabularyMastered: currentMemory.vocabularyMastered,
        accentPreference: currentMemory.accentPreference,
        dailyGoalMinutes: _minutesForGoal(_selectedGoal),
      ),
    );
    await _database.writeSetting('learning_goal', _selectedGoal);
    await _setupRepository.markSetupCompleted();
    if (!mounted) return;
    setState(() => _step = LaunchStep.ready);
  }

  int _minutesForGoal(String goal) {
    return switch (goal) {
      'Grammar Coaching' => 20,
      'Pronunciation' => 10,
      'Vocabulary' => 15,
      _ => 15,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_step == LaunchStep.ready) {
      return const CoachShell();
    }

    return Scaffold(
      body: AppScaffold(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _buildStep(context),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return ListView(
      key: ValueKey(_step),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        _SetupHeader(step: _step),
        const SizedBox(height: 24),
        switch (_step) {
          LaunchStep.welcome => _WelcomeSetup(onContinue: _continueFromWelcome),
          LaunchStep.signIn => _SignInSetup(
            onContinueAsGuest: _continueAsGuest,
            onSignIn: _continueAsGuest,
          ),
          LaunchStep.chooseLevel => _ChooseLevelSetup(
            selectedLevel: _selectedLevel,
            onSelected: _chooseLevel,
            onContinue: _continueFromLevel,
          ),
          LaunchStep.chooseGoal => _ChooseGoalSetup(
            selectedGoal: _selectedGoal,
            onSelected: _chooseGoal,
            onContinue: _finishLightweightSetup,
          ),
          LaunchStep.ready => const SizedBox.shrink(),
        },
      ],
    );
  }
}

enum AiSetupStep {
  permissions,
  deviceCheck,
  modelRecommendation,
  modelDownload,
  modelInitialization,
  ready,
}

class AiSetupWizard extends StatefulWidget {
  const AiSetupWizard({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  State<AiSetupWizard> createState() => _AiSetupWizardState();
}

class _AiSetupWizardState extends State<AiSetupWizard> {
  final _permissionService = AppPermissionService();
  final _deviceService = DeviceCompatibilityService();
  final _modelCatalog = ModelCatalog();
  final _modelLoader = AiModelLoader();
  final _modelInstallRepository = ModelInstallRepository(LocalDatabase.instance);

  AiSetupStep _step = AiSetupStep.permissions;
  PermissionSnapshot? _permissions;
  DeviceProfile? _device;
  AiModelOption? _selectedModel;
  ModelInstallSnapshot? _installSnapshot;
  StreamSubscription<ModelInstallSnapshot>? _installSubscription;
  int _initializationStep = 0;

  @override
  void dispose() {
    _installSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    setState(() => _step = AiSetupStep.permissions);
    final permissions = await _permissionService.requestRequired();
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _step = AiSetupStep.deviceCheck;
    });
    await _runDeviceCheck();
  }

  Future<void> _runDeviceCheck() async {
    final device = await _deviceService.check();
    if (!mounted) return;
    setState(() {
      _device = device;
      _selectedModel = _modelCatalog.recommendedFor(device);
      _step = AiSetupStep.modelRecommendation;
    });
  }

  Future<void> _startDownload() async {
    final model = _selectedModel;
    if (model == null) return;
    setState(() {
      _step = AiSetupStep.modelDownload;
      _installSnapshot = ModelInstallSnapshot(
        status: ModelInstallStatus.downloading,
        progress: 0,
        message: 'Starting ${model.title} AI download...',
      );
    });
    unawaited(
      _modelInstallRepository.saveSnapshot(
        option: model,
        snapshot: _installSnapshot!,
        isRealDownload: AiModelLoader.performsRealDownload,
        localPath: _installSnapshot!.localPath,
      ),
    );

    await _installSubscription?.cancel();
    _installSubscription = _modelLoader
        .downloadAndPrepare(model, authToken: null)
        .listen((snapshot) {
          if (!mounted) return;
          setState(() => _installSnapshot = snapshot);
          if (snapshot.status != ModelInstallStatus.downloading) {
            unawaited(
              _modelInstallRepository.saveSnapshot(
                option: model,
                snapshot: snapshot,
                isRealDownload: AiModelLoader.performsRealDownload,
                localPath: snapshot.localPath,
              ),
            );
          }
          if (snapshot.status == ModelInstallStatus.loaded) {
            _runInitialization();
          }
        });
  }

  Future<void> _runInitialization() async {
    setState(() {
      _step = AiSetupStep.modelInitialization;
      _initializationStep = 0;
    });

    for (var index = 1; index <= 3; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() => _initializationStep = index);
    }

    if (!mounted) return;
    setState(() => _step = AiSetupStep.ready);
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        _AiSetupHeader(step: _step),
        const SizedBox(height: 24),
        switch (_step) {
          AiSetupStep.permissions => _PermissionSetup(
            permissions: _permissions,
            onContinue: _requestPermissions,
          ),
          AiSetupStep.deviceCheck => const _LoadingSetupCard(
            title: 'Checking your device',
            subtitle: 'Measuring RAM, storage, CPU class, and OS readiness.',
          ),
          AiSetupStep.modelRecommendation => _ModelRecommendationSetup(
            device: _device!,
            options: _modelCatalog.optionsFor(_device!),
            selectedModel: _selectedModel!,
            onSelected: (option) => setState(() => _selectedModel = option),
            onContinue: _startDownload,
          ),
          AiSetupStep.modelDownload => _ModelDownloadSetup(
            model: _selectedModel!,
            snapshot: _installSnapshot,
          ),
          AiSetupStep.modelInitialization => _InitializationSetup(
            completedSteps: _initializationStep,
          ),
          AiSetupStep.ready => const _ReadySetup(),
        },
      ],
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.step});

  final LaunchStep step;

  @override
  Widget build(BuildContext context) {
    final current = step.index + 1;
    final total = LaunchStep.ready.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.royalBlue, AppTheme.purple],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AiVerse Speaker',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Offline tutor setup',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 9,
            backgroundColor: AppTheme.royalBlue.withValues(alpha: 0.12),
            color: AppTheme.royalBlue,
          ),
        ),
      ],
    );
  }
}

class _AiSetupHeader extends StatelessWidget {
  const _AiSetupHeader({required this.step});

  final AiSetupStep step;

  @override
  Widget build(BuildContext context) {
    final current = step.index + 1;
    final total = AiSetupStep.ready.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.royalBlue, AppTheme.purple],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Setup Wizard', style: Theme.of(context).textTheme.titleLarge),
                  Text('Download your offline tutor', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 9,
            backgroundColor: AppTheme.royalBlue.withValues(alpha: 0.12),
            color: AppTheme.royalBlue,
          ),
        ),
      ],
    );
  }
}

class _WelcomeSetup extends StatelessWidget {
  const _WelcomeSetup({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome 👋',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Learn English naturally with your AI tutor.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        const AppCard(
          child: Column(
            children: [
              InsightRow(text: 'Speaking Practice'),
              InsightRow(text: 'Grammar Coaching'),
              InsightRow(text: 'Vocabulary'),
              InsightRow(text: 'Pronunciation'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ],
    );
  }
}

class _SignInSetup extends StatelessWidget {
  const _SignInSetup({required this.onSignIn, required this.onContinueAsGuest});

  final VoidCallback onSignIn;
  final VoidCallback onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in or skip', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Start now as a guest. You can sign in later to sync progress.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.person_rounded),
            label: const Text('Sign In'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onContinueAsGuest,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Skip for now'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

class _ChooseLevelSetup extends StatelessWidget {
  const _ChooseLevelSetup({
    required this.selectedLevel,
    required this.onSelected,
    required this.onContinue,
  });

  final String selectedLevel;
  final ValueChanged<String> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const levels = [
      'Beginner A1',
      'Elementary A2',
      'Intermediate B1',
      'Upper Intermediate B2',
      'Advanced C1',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose English level', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...levels.map(
          (level) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceCard(
              title: level,
              selected: selectedLevel == level,
              icon: Icons.signal_cellular_alt_rounded,
              onTap: () => onSelected(level),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ],
    );
  }
}

class _ChooseGoalSetup extends StatelessWidget {
  const _ChooseGoalSetup({
    required this.selectedGoal,
    required this.onSelected,
    required this.onContinue,
  });

  final String selectedGoal;
  final ValueChanged<String> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const goals = [
      (title: 'Speaking Practice', icon: Icons.record_voice_over_rounded),
      (title: 'Grammar Coaching', icon: Icons.edit_note_rounded),
      (title: 'Vocabulary', icon: Icons.menu_book_rounded),
      (title: 'Pronunciation', icon: Icons.hearing_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose goal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...goals.map(
          (goal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceCard(
              title: goal.title,
              selected: selectedGoal == goal.title,
              icon: goal.icon,
              onTap: () => onSelected(goal.title),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.home_rounded),
          label: const Text('Go to Home'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.royalBlue : AppTheme.muted),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.royalBlue : AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadySetup extends StatelessWidget {
  const _ReadySetup();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 56),
          SizedBox(height: 14),
          Text('Ready'),
        ],
      ),
    );
  }
}

class _PermissionSetup extends StatelessWidget {
  const _PermissionSetup({required this.permissions, required this.onContinue});

  final PermissionSnapshot? permissions;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final granted = permissions?.requiredPermissionsReady ?? false;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permissions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Only the essentials are requested for voice practice.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          PermissionRow(
            icon: Icons.mic_rounded,
            title: 'Microphone',
            granted: permissions?.microphoneGranted ?? false,
          ),
          PermissionRow(
            icon: Icons.volume_up_rounded,
            title: 'Audio playback',
            granted: permissions?.audioPlaybackReady ?? false,
          ),
          PermissionRow(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            granted: permissions?.notificationsGranted ?? false,
            optional: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: granted ? null : onContinue,
            icon: Icon(granted ? Icons.check_rounded : Icons.lock_open_rounded),
            label: Text(granted ? 'Permissions ready' : 'Allow Needed Access'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSetupCard extends StatelessWidget {
  const _LoadingSetupCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: 10),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ModelRecommendationSetup extends StatelessWidget {
  const _ModelRecommendationSetup({
    required this.device,
    required this.options,
    required this.selectedModel,
    required this.onSelected,
    required this.onContinue,
  });

  final DeviceProfile device;
  final List<AiModelOption> options;
  final AiModelOption selectedModel;
  final ValueChanged<AiModelOption> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your device supports',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              InsightRow(
                text:
                    '${device.ramGb} GB RAM and ${device.freeStorageGb} GB free storage',
              ),
              InsightRow(
                text: device.supportsFastAiResponses
                    ? 'Fast AI responses'
                    : 'Standard AI responses',
              ),
              InsightRow(
                text: device.supportsOfflineMode
                    ? 'Offline mode'
                    : 'Online mode only',
              ),
              InsightRow(
                text: device.supportsRealtimeConversation
                    ? 'Real-time conversation'
                    : 'Guided turn practice',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recommended for your device',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModelOptionCard(
              option: option,
              selected: option.tier == selectedModel.tier,
              onTap: () => onSelected(option),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.download_rounded),
          label: Text('Download ${selectedModel.title} AI'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ],
    );
  }
}

class _ModelDownloadSetup extends StatelessWidget {
  const _ModelDownloadSetup({required this.model, required this.snapshot});

  final AiModelOption model;
  final ModelInstallSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final progress = snapshot?.progress ?? 0;
    final downloadProgress = snapshot?.downloadProgress ?? 0;
    final extractProgress = snapshot?.extractProgress ?? 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot?.message ?? 'Preparing model download...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Downloading ${model.archivePath} from Cloudflare R2. Keep the app open.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (snapshot?.error != null) ...[
            const SizedBox(height: 12),
            Text(
              snapshot!.error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.coral),
            ),
          ],
          const SizedBox(height: 24),
          _ProgressRow(
            label: 'Download',
            progress: downloadProgress,
            active: snapshot?.status == ModelInstallStatus.downloading,
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Extract',
            progress: extractProgress,
            active: snapshot?.status == ModelInstallStatus.extracting,
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: progress, minHeight: 14),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.wifi_rounded),
                  label: const Text('Wi-Fi Only'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.progress,
    required this.active,
  });

  final String label;
  final double progress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: active ? AppTheme.royalBlue : AppTheme.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 8),
        ),
      ],
    );
  }
}

class _InitializationSetup extends StatelessWidget {
  const _InitializationSetup({required this.completedSteps});

  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Loading language model',
      'Optimizing for your phone',
      'Preparing Emma for conversation',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preparing your AI Tutor...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          ...List.generate(
            steps.length,
            (index) => PermissionRow(
              icon: Icons.auto_awesome_rounded,
              title: steps[index],
              granted: completedSteps > index,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This only happens after installation or updates.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class PermissionRow extends StatelessWidget {
  const PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.granted,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final bool granted;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: granted ? AppTheme.emerald : AppTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            granted
                ? 'Ready'
                : optional
                ? 'Optional'
                : 'Needed',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: granted ? AppTheme.emerald : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class ModelOptionCard extends StatelessWidget {
  const ModelOptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AiModelOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.royalBlue : AppTheme.muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (option.recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Recommended',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${option.downloadSizeGb.toStringAsFixed(1)} GB',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}


