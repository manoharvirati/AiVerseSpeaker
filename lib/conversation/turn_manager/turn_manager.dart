class TurnTimingPolicy {
  const TurnTimingPolicy({this.shortPauseMs = 650, this.longPauseMs = 1400});

  final int shortPauseMs;
  final int longPauseMs;
}

class TurnManager {
  TurnManager({this.policy = const TurnTimingPolicy()});

  final TurnTimingPolicy policy;
  bool wasInterrupted = false;

  bool shouldEndTurn(Duration silence) {
    return silence.inMilliseconds >= policy.longPauseMs;
  }

  bool shouldKeepListening(Duration silence) {
    return silence.inMilliseconds < policy.longPauseMs;
  }

  void markInterrupted() {
    wasInterrupted = true;
  }
}
