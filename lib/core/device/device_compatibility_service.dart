enum PerformanceClass { basic, good, powerful }

class DeviceProfile {
  const DeviceProfile({
    required this.ramGb,
    required this.freeStorageGb,
    required this.cpuClass,
    required this.osVersion,
    required this.supportsOfflineMode,
    required this.supportsRealtimeConversation,
  });

  final int ramGb;
  final int freeStorageGb;
  final PerformanceClass cpuClass;
  final String osVersion;
  final bool supportsOfflineMode;
  final bool supportsRealtimeConversation;

  bool get supportsFastAiResponses =>
      cpuClass != PerformanceClass.basic && ramGb >= 6;
}

class DeviceCompatibilityService {
  Future<DeviceProfile> check() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    return const DeviceProfile(
      ramGb: 8,
      freeStorageGb: 42,
      cpuClass: PerformanceClass.good,
      osVersion: 'Android 14 / iOS 17 ready',
      supportsOfflineMode: true,
      supportsRealtimeConversation: true,
    );
  }
}
