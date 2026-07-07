import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class StreamingTextToSpeech {
  StreamingTextToSpeech({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;
  Timer? _subtitleTimer;
  bool _configured = false;
  bool isSpeaking = false;

  Stream<String> speak(String text) {
    final controller = StreamController<String>();
    final cleanText = text.trim();

    Future<void>(() async {
      try {
        await stop();

        if (cleanText.isEmpty) {
          await controller.close();
          return;
        }

        isSpeaking = true;
        await _configure();
        await _flutterTts.speak(cleanText);

        final words = cleanText
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList(growable: false);
        var index = 0;
        _subtitleTimer = Timer.periodic(const Duration(milliseconds: 120), (
          timer,
        ) async {
          if (controller.isClosed) {
            timer.cancel();
            return;
          }

          if (index >= words.length) {
            timer.cancel();
            isSpeaking = false;
            await controller.close();
            return;
          }

          controller.add(words[index]);
          index += 1;
        });
      } catch (error, stackTrace) {
        isSpeaking = false;
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
    });

    controller.onCancel = () async {
      _subtitleTimer?.cancel();
      await _flutterTts.stop();
      isSpeaking = false;
    };

    return controller.stream;
  }

  Future<void> stop() async {
    _subtitleTimer?.cancel();
    _subtitleTimer = null;
    await _flutterTts.stop();
    isSpeaking = false;
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.46);
    await _flutterTts.setPitch(1);
    await _flutterTts.setVolume(1);
    _configured = true;
  }
}
