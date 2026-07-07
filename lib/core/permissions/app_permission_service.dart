class PermissionSnapshot {
  const PermissionSnapshot({
    required this.microphoneGranted,
    required this.audioPlaybackReady,
    required this.notificationsGranted,
  });

  final bool microphoneGranted;
  final bool audioPlaybackReady;
  final bool notificationsGranted;

  bool get requiredPermissionsReady => microphoneGranted && audioPlaybackReady;
}

class AppPermissionService {
  Future<PermissionSnapshot> requestRequired() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return const PermissionSnapshot(
      microphoneGranted: true,
      audioPlaybackReady: true,
      notificationsGranted: false,
    );
  }
}
