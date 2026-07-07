import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ai/model_loader/ai_model_loader.dart';
import 'ai/model_loader/model_catalog.dart';
import 'ai/inference/local_inference_engine.dart';
import 'ai/prompt_builder/prompt_builder.dart';
import 'conversation/conversation_manager/conversation_manager.dart';
import 'conversation/lesson_engine/lesson_decision_engine.dart';
import 'conversation/turn_manager/turn_manager.dart';
import 'core/device/device_compatibility_service.dart';
import 'core/permissions/app_permission_service.dart';
import 'data/local_database/local_database.dart';
import 'data/repositories/conversation_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/learner_repository.dart';
import 'data/repositories/model_install_repository.dart';
import 'data/repositories/setup_repository.dart';
import 'speech/speech_recognition/streaming_speech_recognizer.dart';
import 'speech/text_to_speech/streaming_text_to_speech.dart';

void main() {
  runApp(const EnglishCoachApp());
}

class EnglishCoachApp extends StatelessWidget {
  const EnglishCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeakFlow AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AppLaunchFlow(),
    );
  }
}

enum LaunchStep {
  welcome,
  permissions,
  deviceCheck,
  modelRecommendation,
  modelDownload,
  modelInitialization,
  ready,
}

class AppLaunchFlow extends StatefulWidget {
  const AppLaunchFlow({super.key});

  @override
  State<AppLaunchFlow> createState() => _AppLaunchFlowState();
}

class _AppLaunchFlowState extends State<AppLaunchFlow> {
  static const _hfTokenFromEnvironment = String.fromEnvironment('HF_TOKEN');

  final _permissionService = AppPermissionService();
  final _deviceService = DeviceCompatibilityService();
  final _modelCatalog = ModelCatalog();
  final _modelLoader = AiModelLoader();
  final _database = LocalDatabase.instance;
  final _hfTokenController = TextEditingController(
    text: _hfTokenFromEnvironment,
  );

  LaunchStep _step = LaunchStep.welcome;
  PermissionSnapshot? _permissions;
  DeviceProfile? _device;
  AiModelOption? _selectedModel;
  ModelInstallSnapshot? _installSnapshot;
  StreamSubscription<ModelInstallSnapshot>? _installSubscription;
  int _initializationStep = 0;

  late final SetupRepository _setupRepository;
  late final ModelInstallRepository _modelInstallRepository;

  @override
  void initState() {
    super.initState();
    _setupRepository = SetupRepository(_database);
    _modelInstallRepository = ModelInstallRepository(_database);
    _restoreSetupState();
  }

  Future<void> _restoreSetupState() async {
    final isCompleted = await _setupRepository.isSetupCompleted();
    if (!mounted || !isCompleted) return;
    setState(() => _step = LaunchStep.ready);
  }

  @override
  void dispose() {
    _installSubscription?.cancel();
    _hfTokenController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    setState(() => _step = LaunchStep.permissions);
    final permissions = await _permissionService.requestRequired();
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _step = LaunchStep.deviceCheck;
    });
    await _runDeviceCheck();
  }

  Future<void> _runDeviceCheck() async {
    final device = await _deviceService.check();
    if (!mounted) return;
    setState(() {
      _device = device;
      _selectedModel = _modelCatalog.recommendedFor(device);
      _step = LaunchStep.modelRecommendation;
    });
  }

  Future<void> _startDownload() async {
    final model = _selectedModel;
    if (model == null) return;
    setState(() {
      _step = LaunchStep.modelDownload;
      _installSnapshot = ModelInstallSnapshot(
        status: ModelInstallStatus.downloading,
        progress: 0,
        message: 'Starting ${model.repositoryId} download...',
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
        .downloadAndPrepare(model, authToken: _hfTokenController.text)
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
      _step = LaunchStep.modelInitialization;
      _initializationStep = 0;
    });

    for (var index = 1; index <= 3; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() => _initializationStep = index);
    }

    if (!mounted) return;
    await _setupRepository.markSetupCompleted();
    if (!mounted) return;
    setState(() => _step = LaunchStep.ready);
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
          LaunchStep.welcome => _WelcomeSetup(onContinue: _requestPermissions),
          LaunchStep.permissions => _PermissionSetup(
            permissions: _permissions,
            onContinue: _requestPermissions,
          ),
          LaunchStep.deviceCheck => const _LoadingSetupCard(
            title: 'Checking your device',
            subtitle: 'Measuring RAM, storage, CPU class, and OS readiness.',
          ),
          LaunchStep.modelRecommendation => _ModelRecommendationSetup(
            device: _device!,
            options: _modelCatalog.optionsFor(_device!),
            selectedModel: _selectedModel!,
            onSelected: (option) => setState(() => _selectedModel = option),
            tokenController: _hfTokenController,
            onContinue: _startDownload,
          ),
          LaunchStep.modelDownload => _ModelDownloadSetup(
            model: _selectedModel!,
            snapshot: _installSnapshot,
          ),
          LaunchStep.modelInitialization => _InitializationSetup(
            completedSteps: _initializationStep,
          ),
          LaunchStep.ready => const SizedBox.shrink(),
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
                    'SpeakFlow AI',
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

class _WelcomeSetup extends StatelessWidget {
  const _WelcomeSetup({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meet your AI English Tutor',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Set up once, then practice private, natural conversations even offline.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        const AppCard(
          child: Column(
            children: [
              InsightRow(text: 'Works offline after model setup'),
              InsightRow(text: 'Private conversations stay on your device'),
              InsightRow(text: 'Natural voice practice with instant coaching'),
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
    required this.tokenController,
    required this.onContinue,
  });

  final DeviceProfile device;
  final List<AiModelOption> options;
  final AiModelOption selectedModel;
  final ValueChanged<AiModelOption> onSelected;
  final TextEditingController tokenController;
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
        if (selectedModel.requiresAuthToken) ...[
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hugging Face Access',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${selectedModel.repositoryId} is gated. Paste a Hugging Face token from an account with Gemma access.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.key_rounded),
                    labelText: 'HF token',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            'Downloading from ${model.repositoryId}. Keep the app open.',
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
                  onPressed: () {},
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
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

class AppTheme {
  static const royalBlue = Color(0xFF2563EB);
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF22C55E);
  static const purple = Color(0xFF7C3AED);
  static const violet = Color(0xFFA855F7);
  static const sky = Color(0xFF38BDF8);
  static const orange = Color(0xFFF59E0B);
  static const coral = Color(0xFFFB7185);
  static const offWhite = Color(0xFFF8FAFC);
  static const navy = Color(0xFF09090B);
  static const surface = Color(0xFF18181B);
  static const card = Color(0xFF111327);
  static const ink = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A1AA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.light,
      primary: royalBlue,
      secondary: emerald,
      surface: Colors.white,
      error: coral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: offWhite,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _textTheme(Brightness.light),
      navigationBarTheme: _navigationBarTheme(scheme),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
      primary: purple,
      secondary: sky,
      surface: surface,
      error: coral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _textTheme(Brightness.dark),
      navigationBarTheme: _navigationBarTheme(scheme),
      iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? Colors.white : ink;
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
      displaySmall: TextStyle(
        color: color,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineMedium: TextStyle(
        color: color,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: color, fontSize: 16, height: 1.45),
      bodyMedium: const TextStyle(color: muted, fontSize: 14, height: 1.45),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
    );
  }

  static NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : AppTheme.muted,
        ),
      ),
    );
  }
}

class CoachShell extends StatefulWidget {
  const CoachShell({super.key});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onStartSpeaking: () => setState(() => _index = 2)),
      const ExploreScreen(),
      const PracticeScreen(),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onStartSpeaking});

  final VoidCallback onStartSpeaking;

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
              const SizedBox(height: 18),
              StatsStrip(data: data),
              const SizedBox(height: 18),
              ContinueLessonCard(
                lesson: data.recommendedLesson,
                modelInstall: data.modelInstall,
                onStartSpeaking: widget.onStartSpeaking,
              ),
              const SizedBox(height: 22),
              SectionTitle(
                title: 'Quick Start',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('See All Topics'),
                ),
              ),
              const SizedBox(height: 12),
              QuickStartRail(lessons: data.lessons),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TodaysGoalCard(data: data)),
                  const SizedBox(width: 14),
                  Expanded(child: HomeSkillsCard(data: data)),
                ],
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
          onPressed: () {},
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
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 24, 18, 18),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 4,
            bottom: 0,
            child: TutorIllustration(
              label: 'Let\'s speak!',
              color: colorFromHex(data.activeTutor?.colorHex ?? '7C3AED'),
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI TUTOR',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.violet,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Practice English\nAnytime, Anywhere',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'All conversations, feedback and analysis happen on your device.',
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
        ],
      ),
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

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
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
      ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopicArt(category: lesson.category, title: lesson.title, size: 112),
          const SizedBox(width: 16),
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
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            height: 72,
            child: FilledButton(
              onPressed: onStartSpeaking,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 38),
            ),
          ),
        ],
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
          IconButton.filled(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

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

          final lesson = data.recommendedLesson;

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
          onPressed: () {},
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
          onPressed: () {},
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
        TopicArt(category: lesson.category, title: lesson.title, size: 420),
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
    return GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (average / 100).clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: AppTheme.emerald,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$average%',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text('Overall', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
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
          Row(
            children: List.generate(
              data.dailyActivity.length,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 42,
                        height: 42,
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
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.dailyActivity[index].dayLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final DashboardRepository _dashboardRepository;
  late Future<List<LessonSummary>> _lessonsFuture;
  String _query = '';
  String _difficulty = 'All';

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
            return matchesQuery && matchesDifficulty;
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
                action: TextButton(onPressed: () {}, child: const Text('View All')),
              ),
              const SizedBox(height: 12),
              CategoryCarousel(categories: categories, lessons: lessons),
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
                          option.repositoryId,
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
          onPressed: () {},
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Topics', style: Theme.of(context).textTheme.headlineMedium),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.filter_alt_rounded)),
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
                Row(
                  children: [
                    HeroMetric(icon: Icons.category_rounded, value: '$categories', label: 'Categories'),
                    const SizedBox(width: 16),
                    HeroMetric(icon: Icons.article_rounded, value: '$topics', label: 'Topics'),
                    const SizedBox(width: 16),
                    HeroMetric(icon: Icons.check_circle_rounded, value: '$completed', label: 'Completed'),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.emerald, size: 20),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class CategoryCarousel extends StatelessWidget {
  const CategoryCarousel({super.key, required this.categories, required this.lessons});

  final List<String> categories;
  final List<LessonSummary> lessons;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = categories[index];
          final count = lessons.where((lesson) => lesson.category == category).length;
          final color = colorForCategory(category);
          return SizedBox(
            width: 122,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconForCategory(category), color: color, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    category,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('$count Topics', style: Theme.of(context).textTheme.bodyMedium),
                ],
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
            action: TextButton(onPressed: () {}, child: const Text('View All')),
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
        IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.settings_rounded)),
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
    return GlassCard(
      child: Row(
        children: [
          Expanded(child: ProfileMetric(icon: Icons.schedule_rounded, value: '${practiced}m', label: 'Time Practiced', color: AppTheme.emerald)),
          Expanded(child: ProfileMetric(icon: Icons.track_changes_rounded, value: '$completed', label: 'Topics Completed', color: AppTheme.sky)),
          Expanded(child: ProfileMetric(icon: Icons.trending_up_rounded, value: '$average%', label: 'Average Score', color: AppTheme.orange)),
          Expanded(child: ProfileMetric(icon: Icons.emoji_events_rounded, value: '$unlocked', label: 'Achievements', color: AppTheme.violet)),
        ],
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
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
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
    });
  }

  Future<void> _writeSetting(String key, String value) async {
    await LocalDatabase.instance.writeSetting(key, value);
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
          decoration: const BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: Colors.white24,
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
                  memory: widget.memory,
                  onNotificationsChanged: (value) => _writeSetting(
                    'notifications',
                    value.toString(),
                  ),
                  onSpeechSpeedChanged: (value) => _writeSetting(
                    'speech_speed',
                    value.toStringAsFixed(2),
                  ),
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
                        Text(option.repositoryId, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
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
    required this.memory,
    required this.onNotificationsChanged,
    required this.onSpeechSpeedChanged,
  });

  final String title;
  final String value;
  final bool notifications;
  final double speechSpeed;
  final LearnerMemory memory;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<double> onSpeechSpeedChanged;

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
          const Divider(color: Colors.white12),
          Text('Speech speed', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: speechSpeed.clamp(0.2, 0.8),
            min: 0.2,
            max: 0.8,
            divisions: 6,
            label: speechSpeed.toStringAsFixed(2),
            onChanged: onSpeechSpeedChanged,
          ),
          const Divider(color: Colors.white12),
          InsightRow(text: 'Language: ${memory.accentPreference}'),
          const InsightRow(text: 'Privacy: all learning data remains local in SQLite.'),
          const InsightRow(text: 'Theme: premium dark mode.'),
        ],
      ),
    );
  }
}

class QuickStartRail extends StatelessWidget {
  const QuickStartRail({super.key, required this.lessons});

  final List<LessonSummary> lessons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final lesson = lessons[index % lessons.length];
          final color = colorForCategory(lesson.category);
          return SizedBox(
            width: 118,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconForCategory(lesson.category), color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lesson.category,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lessons.where((item) => item.category == lesson.category).length} Topics',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
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
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
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
          Text(label, style: Theme.of(context).textTheme.labelLarge),
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
            color: AppTheme.card.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
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
            onPressed: () {},
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
          children: [
            TopicArt(category: lesson.category, title: lesson.title, size: 112),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    lesson.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${lesson.estimatedMinutes}-${lesson.estimatedMinutes + 2} min',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_rounded, size: 16, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'AI Role: ${roleForCategory(lesson.category)}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              height: 104,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    onPressed: onToggleSaved,
                    icon: Icon(
                      lesson.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: lesson.saved ? AppTheme.violet : AppTheme.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(lesson.progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium,
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
    required this.onToggleSaved,
  });

  final LessonSummary lesson;
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
          decoration: const BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: Colors.white24,
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
              TopicArt(category: lesson.category, title: lesson.title, size: 360),
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
                onPressed: () => Navigator.of(context).pop(),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
                    ),
                  ),
        ],
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
