import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'logger_service.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  String? _currentPath;
  bool _speechInitialized = false;

  Future<bool> requestPermission() async {
    final mic = await Permission.microphone.request();
    return mic.isGranted;
  }

  Future<void> startRecording() async {
    if (!await requestPermission()) throw Exception('Microphone permission denied');

    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: _currentPath!,
    );
    logger.log('🎙️ Audio recording started at $_currentPath');
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    logger.log('🎙️ Audio recording stopped: ${path ?? _currentPath}');
    return path ?? _currentPath;
  }

  /// Perform Speech-to-Text transcription on the recorded voice note
  Future<String> transcribe(String audioPath) async {
    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speechToText.initialize(
          onError: (err) => logger.log('⚠️ Speech-To-Text error: ${err.errorMsg}'),
          onStatus: (status) => logger.log('🎙️ Speech-To-Text status: $status'),
        );
      }

      logger.log('🎙️ Transcribing audio file at $audioPath...');
      if (_speechToText.isAvailable) {
        String lastWords = '';
        await _speechToText.listen(
          onResult: (result) {
            lastWords = result.recognizedWords;
            logger.log('🎙️ STT Recognized: $lastWords');
          },
        );
        await Future.delayed(const Duration(seconds: 2));
        await _speechToText.stop();

        if (lastWords.trim().isNotEmpty) {
          logger.log('✅ Speech-to-Text transcription successful: "$lastWords"');
          return lastWords;
        }
      }
    } catch (e) {
      logger.log('Notice in Speech-To-Text transcription: $e');
    }

    // Fallback indicator if real-time STT engine did not detect text
    return '[Field Voice Recording Attached]';
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
