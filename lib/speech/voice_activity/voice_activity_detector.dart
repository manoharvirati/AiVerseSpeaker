class VoiceActivitySnapshot {
  const VoiceActivitySnapshot({
    required this.isSpeaking,
    required this.silenceDuration,
  });

  final bool isSpeaking;
  final Duration silenceDuration;
}

class VoiceActivityDetector {
  VoiceActivitySnapshot evaluate(double inputLevel) {
    return VoiceActivitySnapshot(
      isSpeaking: inputLevel > 0.18,
      silenceDuration: inputLevel > 0.18
          ? Duration.zero
          : const Duration(milliseconds: 900),
    );
  }
}
