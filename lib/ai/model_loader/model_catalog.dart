import '../../core/device/device_compatibility_service.dart';

enum ModelTier { fast, balanced, advanced }

class AiModelOption {
  const AiModelOption({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.downloadSizeGb,
    required this.internalModelId,
    required this.archivePath,
    required this.recommended,
  });

  final ModelTier tier;
  final String title;
  final String subtitle;
  final double downloadSizeGb;
  final String internalModelId;
  final String archivePath;
  final bool recommended;

  String get sourceLabel => archivePath;
}

class ModelCatalog {
  List<AiModelOption> allOptions() {
    return _options(recommendFast: true, advancedAllowed: true);
  }

  List<AiModelOption> optionsFor(DeviceProfile device) {
    final advancedAllowed =
        device.cpuClass == PerformanceClass.powerful && device.ramGb >= 10;
    return _options(
      recommendFast: device.supportsFastAiResponses,
      advancedAllowed: advancedAllowed,
    );
  }

  List<AiModelOption> _options({
    required bool recommendFast,
    required bool advancedAllowed,
  }) {
    return [
      AiModelOption(
        tier: ModelTier.fast,
        title: 'Fast',
        subtitle: 'Gemma 3 1B. Quick responses with lower battery usage.',
        downloadSizeGb: 1.2,
        internalModelId: 'aiverseworld-model-fast',
        archivePath: 'fast/speaker-gemma3-1b-it-q4.zip',
        recommended: recommendFast,
      ),
      AiModelOption(
        tier: ModelTier.balanced,
        title: 'Medium',
        subtitle: 'Cloud model package. Better quality for everyday lessons.',
        downloadSizeGb: 2,
        internalModelId: 'aiverseworld-model-medium',
        archivePath: 'aiverseworld-model/medium/model.zip',
        recommended: !recommendFast,
      ),
      AiModelOption(
        tier: ModelTier.advanced,
        title: 'Best',
        subtitle: advancedAllowed
            ? 'Cloud model package. Highest quality for powerful devices.'
            : 'Available later on stronger devices.',
        downloadSizeGb: 3.8,
        internalModelId: 'aiverseworld-model-best',
        archivePath: 'aiverseworld-model/best/model.zip',
        recommended: false,
      ),
    ];
  }

  AiModelOption recommendedFor(DeviceProfile device) {
    return optionsFor(device).firstWhere((option) => option.recommended);
  }
}
