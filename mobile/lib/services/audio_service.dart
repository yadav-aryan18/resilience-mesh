import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

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
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path ?? _currentPath;
  }

  Future<String> transcribe(String audioPath) async {
    // Return placeholder to be filled by edge model
    return '[AUDIO_TRANSCRIPT_PLACEHOLDER]';
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
