import '../../core/device/device_compatibility_service.dart';

enum ModelTier { fast, balanced, advanced }

class AiModelOption {
  const AiModelOption({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.downloadSizeGb,
    required this.internalModelId,
    required this.repositoryId,
    required this.requiresAuthToken,
    required this.recommended,
  });

  final ModelTier tier;
  final String title;
  final String subtitle;
  final double downloadSizeGb;
  final String internalModelId;
  final String repositoryId;
  final bool requiresAuthToken;
  final bool recommended;
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
        downloadSizeGb: 1.5,
        internalModelId: 'google/gemma-3-1b-it',
        repositoryId: 'google/gemma-3-1b-it',
        requiresAuthToken: true,
        recommended: recommendFast,
      ),
      AiModelOption(
        tier: ModelTier.balanced,
        title: 'Medium',
        subtitle: 'Gemma 3 4B. Better quality for everyday lessons.',
        downloadSizeGb: 2,
        internalModelId: 'google/gemma-3-4b-it',
        repositoryId: 'google/gemma-3-4b-it',
        requiresAuthToken: true,
        recommended: !recommendFast,
      ),
      AiModelOption(
        tier: ModelTier.advanced,
        title: 'Best',
        subtitle: advancedAllowed
            ? 'Gemma 3 12B. Highest quality for powerful devices.'
            : 'Available later on stronger devices.',
        downloadSizeGb: 3.8,
        internalModelId: 'google/gemma-3-12b-it',
        repositoryId: 'google/gemma-3-12b-it',
        requiresAuthToken: true,
        recommended: false,
      ),
    ];
  }

  AiModelOption recommendedFor(DeviceProfile device) {
    return optionsFor(device).firstWhere((option) => option.recommended);
  }
}
