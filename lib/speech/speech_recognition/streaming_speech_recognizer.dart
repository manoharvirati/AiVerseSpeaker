import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class StreamingSpeechRecognizer {
  StreamingSpeechRecognizer({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  Stream<String> listen() {
    final controller = StreamController<String>();
    Timer? fallbackTimer;

    Future<void>(() async {
      final available = await _speechToText.initialize();
      if (!available) {
        _startFallback(controller, (timer) => fallbackTimer = timer);
        return;
      }

      // ignore: deprecated_member_use
      await _speechToText.listen(
        // ignore: deprecated_member_use
        listenFor: const Duration(seconds: 12),
        // ignore: deprecated_member_use
        pauseFor: const Duration(seconds: 3),
        // ignore: deprecated_member_use
        partialResults: true,
        onResult: (SpeechRecognitionResult result) {
          if (!controller.isClosed && result.recognizedWords.trim().isNotEmpty) {
            controller.add(result.recognizedWords.trim());
          }
          if (result.finalResult && !controller.isClosed) {
            controller.close();
          }
        },
      );

      Timer(const Duration(seconds: 13), () {
        if (!controller.isClosed) controller.close();
      });
    });

    controller.onCancel = () async {
      fallbackTimer?.cancel();
      await _speechToText.stop();
    };

    return controller.stream;
  }

  void _startFallback(
    StreamController<String> controller,
    void Function(Timer timer) setTimer,
  ) {
    final samples = ['I would', 'I would like', 'I would like a cappuccino, please.'];
    var index = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      controller.add(samples[index]);
      index += 1;
      if (index == samples.length) {
        timer.cancel();
        controller.close();
      }
    });
    setTimer(timer);
  }
}
