import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/triage_model.dart';

/// Text-To-Speech guidance service for hands-free first-aid protocol readout
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.45); // Slower rate for clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      if (kIsWeb) return;
      if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      }

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });
    } catch (e) {
      debugPrint('TTS initialization notice: $e');
    }
  }

  /// Speak entire triage summary and numbered steps
  Future<void> speakTriage(TriageResult result) async {
    await stop();

    final buffer = StringBuffer();
    buffer.writeln('Urgency level: ${result.urgencyLabel}.');
    buffer.writeln(result.summary);
    buffer.writeln('First aid steps:');

    for (int i = 0; i < result.steps.length; i++) {
      buffer.writeln('Step ${i + 1}: ${result.steps[i]}.');
    }

    if (result.evacuationRoute != null && result.evacuationRoute!.isNotEmpty) {
      buffer.writeln('Evacuation guidance: ${result.evacuationRoute}.');
    }

    _isSpeaking = true;
    await _flutterTts.speak(buffer.toString());
  }

  /// Speak a single specific step
  Future<void> speakStep(int stepIndex, String text) async {
    await stop();
    _isSpeaking = true;
    await _flutterTts.speak('Step ${stepIndex + 1}: $text');
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }

  void dispose() {
    stop();
  }
}
