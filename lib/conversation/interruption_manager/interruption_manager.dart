class InterruptionManager {
  bool shouldStopTutorAudio({
    required bool tutorIsSpeaking,
    required bool userVoiceDetected,
  }) {
    return tutorIsSpeaking && userVoiceDetected;
  }
}
