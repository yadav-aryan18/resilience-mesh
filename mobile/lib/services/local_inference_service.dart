import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import '../models/triage_model.dart';
import 'logger_service.dart';
import 'zip_stream_packager.dart';

/// On-device Gemma inference engine (Gemma 4 E2B/E4B or Gemma 2B Edge)
/// Auto-detects TFL3 model binary headers and packages 2GB+ model files
/// into valid MediaPipe .task Zip bundles on-device with zero-RAM streaming.
class LocalInferenceService {
  bool _isModelLoaded = false;
  String? _modelPath;
  String _activeModelName = 'gemma-4-edge';
  ModelFileType _detectedFileType = ModelFileType.task;
  String? _lastError;

  bool get isReady => _isModelLoaded;
  String? get modelPath => _modelPath;
  String get activeModelName => _activeModelName;
  String? get lastError => _lastError;

  Future<File?> _ensureTokenizerFile() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final tokenizerFile = File('${docsDir.path}/tokenizer.model');
      if (!await tokenizerFile.exists() || await tokenizerFile.length() < 1000000) {
        logger.log('📦 Extracting Gemma tokenizer.model asset (4.1MB) to sandbox...');
        final byteData = await rootBundle.load('assets/models/tokenizer.model');
        final buffer = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        await tokenizerFile.writeAsBytes(buffer, flush: true);
        logger.log('✅ Gemma tokenizer.model extracted cleanly (${buffer.length} bytes)');
      }
      return tokenizerFile;
    } catch (e) {
      logger.log('⚠️ Could not load Gemma tokenizer asset: $e');
      return null;
    }
  }

  /// Initialize and verify the Gemma model binary (.bin / .task file)
  Future<bool> loadModel({String? customModelPath}) async {
    _lastError = null;
    try {
      if (customModelPath != null && customModelPath.isNotEmpty) {
        logger.log('🔍 Model pick request: $customModelPath');
        final file = File(customModelPath);
        if (!await file.exists()) {
          _lastError = 'Model file not found at $customModelPath';
          logger.log('❌ $_lastError');
          _isModelLoaded = false;
          return false;
        }

        final fileLength = await file.length();
        final fileName = file.path.split('/').last;
        _activeModelName = fileName;
        logger.log('📄 Picked file size: $fileLength bytes ($fileName)');

        if (fileLength == 0) {
          _lastError = 'Picked model file is 0 bytes (empty file or un-downloaded cloud file)';
          logger.log('❌ $_lastError');
          _isModelLoaded = false;
          return false;
        }

        final docsDir = await getApplicationDocumentsDirectory();

        // Read magic header bytes to auto-detect file format (Zip .task vs TFL3 LiteRT binary)
        bool isZip = false;
        bool isTfl3 = false;
        try {
          final stream = file.openRead(0, 16);
          final firstBytes = await stream.first;
          final hexHeader = firstBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          logger.log('🔍 File magic header bytes: $hexHeader');

          isZip = firstBytes.length >= 4 &&
              firstBytes[0] == 0x50 &&
              firstBytes[1] == 0x4B &&
              firstBytes[2] == 0x03 &&
              firstBytes[3] == 0x04;

          isTfl3 = firstBytes.length >= 8 &&
              firstBytes[4] == 0x54 &&
              firstBytes[5] == 0x46 &&
              firstBytes[6] == 0x4C &&
              firstBytes[7] == 0x33;
        } catch (hdrErr) {
          logger.log('⚠️ Could not inspect file header bytes: $hdrErr');
        }

        String targetPath;
        if (isTfl3) {
          logger.log('✨ Header is TFL3 binary. Zero-RAM streaming into MediaPipe .task Zip bundle...');
          final baseName = fileName.replaceAll('.task', '').replaceAll('.bin', '').replaceAll('.tflite', '');
          targetPath = '${docsDir.path}/${baseName}_v5_tokenizer_bundled.task';
          final targetFile = File(targetPath);

          // Clean up legacy bundle files to reclaim storage space
          try {
            final oldV1 = File('${docsDir.path}/${baseName}_bundled.task');
            if (await oldV1.exists()) await oldV1.delete();
            final oldV2 = File('${docsDir.path}/${baseName}_v2_bundled.task');
            if (await oldV2.exists()) await oldV2.delete();
            final oldV3 = File('${docsDir.path}/${baseName}_v3_prefill_bundled.task');
            if (await oldV3.exists()) await oldV3.delete();
            final oldV4 = File('${docsDir.path}/${baseName}_v4_uppercase_bundled.task');
            if (await oldV4.exists()) await oldV4.delete();
          } catch (_) {}

          final tokenizerFile = await _ensureTokenizerFile();

          if (!await targetFile.exists() || await targetFile.length() < fileLength) {
            final configJson = '{\n  "model_type": "GEMMA_IT"\n}\n';
            final success = await ZipStreamPackager.createMediaPipeTaskBundle(
              inputFile: file,
              outputFile: targetFile,
              tokenizerFile: tokenizerFile,
              configJson: configJson,
              logger: (msg) => logger.log(msg),
            );

            if (!success || !await targetFile.exists()) {
              _lastError = 'Failed to create MediaPipe Zip bundle on disk';
              logger.log('❌ $_lastError');
              _isModelLoaded = false;
              return false;
            }
          } else {
            final bundleSize = await targetFile.length();
            logger.log('ℹ️ MediaPipe Zip bundle already exists at $targetPath ($bundleSize bytes).');
          }
          _detectedFileType = ModelFileType.task;
        } else {
          targetPath = '${docsDir.path}/$fileName';
          final sandboxFile = File(targetPath);
          if (!await sandboxFile.exists() || await sandboxFile.length() != fileLength) {
            logger.log('📦 Copying model to app sandbox: $targetPath ($fileLength bytes)...');
            await file.copy(targetPath);
            final copySize = await sandboxFile.length();
            logger.log('✅ Model copied to sandbox successfully ($copySize bytes).');
          } else {
            logger.log('ℹ️ Sandbox copy already exists at $targetPath ($fileLength bytes).');
          }
          _detectedFileType = isZip ? ModelFileType.task : ModelFileType.binary;
        }

        _modelPath = targetPath;

        // Initialize FlutterGemma and install model spec into FlutterGemma engine
        try {
          await FlutterGemma.initialize();
          logger.log('FlutterGemma.initialize() completed.');

          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
            fileType: _detectedFileType,
          ).fromFile(_modelPath!).install();
          logger.log('✅ FlutterGemma.installModel() installed spec cleanly (fileType=$_detectedFileType).');
        } catch (e) {
          logger.log('FlutterGemma.installModel notice: $e');
        }

        _isModelLoaded = true;
        logger.log('🧠 On-Device Gemma model ready: $_activeModelName (path: $_modelPath, type: $_detectedFileType)');
        return true;
      }

      _isModelLoaded = false;
      return false;
    } catch (e) {
      _lastError = e.toString();
      logger.log('⚠️ On-device Gemma initialization notice: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Perform on-device inference using Gemma LLM or fallback engine
  Future<TriageResult> infer({
    Uint8List? imageBytes,
    String? audioTranscript,
    required String textQuery,
  }) async {
    final stopwatch = Stopwatch()..start();
    _lastError = null;

    logger.log('🚀 Starting infer() query: "$textQuery"');

    // Try executing real Gemma LLM if model path is set
    if (_isModelLoaded && _modelPath != null) {
      try {
        final prompt = _buildGemmaPrompt(
          textQuery: textQuery,
          audioTranscript: audioTranscript,
          hasImage: imageBytes != null && imageBytes.isNotEmpty,
        );

        final String? rawResponse = await _executeGemmaInference(prompt, imageBytes: imageBytes);
        stopwatch.stop();

        if (rawResponse != null && rawResponse.trim().isNotEmpty) {
          logger.log('🎉 Gemma inference completed successfully in ${stopwatch.elapsedMilliseconds} ms!');
          return TriageResult.fromRawLlmResponse(
            rawResponse,
            latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
            modelName: _activeModelName,
          );
        }
      } catch (e) {
        _lastError = e.toString();
        logger.log('❌ Gemma LLM execution exception: $e. Falling back to edge classifier.');
      }
    } else {
      logger.log('ℹ️ Model not loaded (_isModelLoaded=$_isModelLoaded, _modelPath=$_modelPath). Skipping LLM execution.');
    }

    // Fallback: Rule-based edge heuristic classifier
    stopwatch.stop();
    final urgency = _classifyUrgencyHeuristic(textQuery, audioTranscript);
    final steps = _generateHeuristicSteps(textQuery, urgency);

    final summary = _lastError != null
        ? '⚠️ Local Gemma Notice: $_lastError\n\nFallback Triage: ${_generateHeuristicSummary(textQuery, audioTranscript)}'
        : _generateHeuristicSummary(textQuery, audioTranscript);

    return TriageResult.fromLocalJson({
      'urgency': urgency.name,
      'summary': summary,
      'steps': steps,
      'latency_ms': stopwatch.elapsedMilliseconds.toDouble(),
      'model': _isModelLoaded ? 'gemma-4-fallback' : 'edge-heuristic-rule-engine',
    });
  }

  /// Helper to execute native MediaPipe GenAI inference
  Future<String?> _executeGemmaInference(String prompt, {Uint8List? imageBytes}) async {
    if (_modelPath == null || _modelPath!.isEmpty) {
      logger.log('❌ _executeGemmaInference aborted: _modelPath is null/empty');
      return null;
    }

    // 1. Try Modern FlutterGemma API first
    try {
      if (FlutterGemma.hasActiveModel()) {
        logger.log('🧠 Executing inference via FlutterGemma.getActiveModel()...');
        final model = await FlutterGemma.getActiveModel(
          maxTokens: 512,
          preferredBackend: PreferredBackend.gpu,
        );
        final session = await model.createSession(temperature: 0.2);
        await session.addQueryChunk(Message.text(text: prompt));
        final response = await session.getResponse();
        await session.close();
        await model.close();
        if (response.trim().isNotEmpty) {
          logger.log('✅ FlutterGemma getActiveModel (GPU) returned response (${response.length} chars)');
          return response;
        }
      }
    } catch (e) {
      logger.log('⚠️ FlutterGemma getActiveModel GPU notice: $e. Trying CPU backend.');
      try {
        if (FlutterGemma.hasActiveModel()) {
          final model = await FlutterGemma.getActiveModel(
            maxTokens: 512,
            preferredBackend: PreferredBackend.cpu,
          );
          final session = await model.createSession(temperature: 0.2);
          await session.addQueryChunk(Message.text(text: prompt));
          final response = await session.getResponse();
          await session.close();
          await model.close();
          if (response.trim().isNotEmpty) {
            logger.log('✅ FlutterGemma getActiveModel (CPU) returned response (${response.length} chars)');
            return response;
          }
        }
      } catch (cpuErr) {
        logger.log('⚠️ FlutterGemma getActiveModel CPU notice: $cpuErr.');
      }
    }

    // 2. Direct Pigeon PlatformService fallback
    final platform = PlatformService();
    bool modelCreated = false;
    for (final backend in [PreferredBackend.gpu, PreferredBackend.cpu]) {
      try {
        logger.log('🧠 MediaPipe PlatformService createModel -> Backend: $backend | Path: $_modelPath');
        await platform.createModel(
          maxTokens: 512,
          modelPath: _modelPath!,
          loraRanks: const [4, 8, 16],
          preferredBackend: backend,
          maxNumImages: imageBytes != null ? 1 : null,
        );
        modelCreated = true;
        logger.log('✅ MediaPipe PlatformService createModel succeeded on $backend');
        break;
      } catch (e) {
        logger.log('⚠️ MediaPipe PlatformService createModel failed on backend $backend: $e');
        if (e.toString().contains('interpreter != nullptr') || _activeModelName.toLowerCase().contains('-web')) {
          _lastError = 'Model file "$_activeModelName" is compiled for Web/WebGPU (LiteRT-Web target). Native Android requires an Android target model (e.g. gemma-2b-it-gpu-int4.bin). Running Edge Triage Engine.';
        } else {
          _lastError = 'MediaPipe model creation ($backend) failed: $e';
        }
      }
    }

    if (!modelCreated) {
      logger.log('❌ Could not create MediaPipe model on GPU or CPU. Error: $_lastError');
      return null;
    }

    try {
      logger.log('🧠 MediaPipe PlatformService createSession starting...');
      await platform.createSession(
        temperature: 0.2,
        randomSeed: 42,
        topK: 40,
        enableVisionModality: imageBytes != null,
      );

      await platform.addQueryChunk(prompt);
      if (imageBytes != null && imageBytes.isNotEmpty) {
        await platform.addImage(imageBytes);
      }

      final response = await platform.generateResponse();
      logger.log('✅ Real Gemma inference output received (${response.length} chars)');

      try {
        await platform.closeSession();
        await platform.closeModel();
      } catch (_) {}

      return response;
    } catch (e) {
      logger.log('❌ Error during Gemma generation: $e');
      _lastError = 'Gemma inference execution failed: $e';
      try {
        await platform.closeSession();
        await platform.closeModel();
      } catch (_) {}
      return null;
    }
  }

  /// Construct structured prompt for Gemma instruction format
  String _buildGemmaPrompt({
    required String textQuery,
    String? audioTranscript,
    bool hasImage = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<start_of_turn>user');
    buffer.writeln('You are ResilienceMesh Edge AI — an emergency first-aid triage system operating offline.');
    buffer.writeln('Analyze the field report and provide urgent medical / tactical instructions.');
    buffer.writeln();
    buffer.writeln('FIELD REPORT:');
    buffer.writeln('- Text Query: $textQuery');
    if (audioTranscript != null && audioTranscript.isNotEmpty) {
      buffer.writeln('- Audio Transcript: $audioTranscript');
    }
    if (hasImage) {
      buffer.writeln('- Injury Photo Attached: Yes');
    }
    buffer.writeln();
    buffer.writeln('Return JSON with:');
    buffer.writeln('{"urgency": "red"|"yellow"|"green", "summary": "brief summary", "steps": ["step 1", "step 2"], "evacuation_route": "if hazard present"}<end_of_turn>');
    buffer.writeln('<start_of_turn>model');
    return buffer.toString();
  }

  UrgencyLevel _classifyUrgencyHeuristic(String text, String? audio) {
    final combined = '$text ${audio ?? ""}'.toLowerCase();
    if (combined.contains('severe') ||
        combined.contains('bleeding') ||
        combined.contains('unconscious') ||
        combined.contains('not breathing') ||
        combined.contains('critical') ||
        combined.contains('burn')) {
      return UrgencyLevel.red;
    }
    if (combined.contains('moderate') ||
        combined.contains('fracture') ||
        combined.contains('pain') ||
        combined.contains('victim') ||
        combined.contains('sprain')) {
      return UrgencyLevel.yellow;
    }
    return UrgencyLevel.green;
  }

  List<String> _generateHeuristicSteps(String query, UrgencyLevel urgency) {
    if (urgency == UrgencyLevel.red) {
      return [
        'Call for immediate medical evacuation if possible',
        'Apply direct pressure to bleeding wounds using clean cloth',
        'Do NOT move victim unless in immediate environmental danger',
        'Check airway and pulse every 60 seconds',
        'Keep victim warm with blanket or jacket to prevent shock',
      ];
    }
    if (urgency == UrgencyLevel.yellow) {
      return [
        'Ensure scene is safe before approaching',
        'Immobilize any suspected fractures using rigid splint',
        'Clean open wounds with clean water and cover',
        'Monitor victim for signs of deterioration or shock',
        'Prepare for evacuation if conditions worsen',
      ];
    }
    return [
      'Document injuries and environmental hazards',
      'Provide reassurance and basic comfort',
      'Monitor for delayed symptom onset',
      'Report location and status to command center',
    ];
  }

  String _generateHeuristicSummary(String text, String? audio) {
    final input = audio ?? text;
    final keywords = _extractKeywords(input);
    return 'On-device triage complete. Key indicators detected: $keywords. '
        'Follow immediate steps below. Toggle Expert Mode if laptop node is reachable.';
  }

  String _extractKeywords(String input) {
    final keywords = <String>[];
    final lower = input.toLowerCase();
    if (lower.contains('bleeding')) keywords.add('hemorrhage');
    if (lower.contains('fracture')) keywords.add('fracture');
    if (lower.contains('water') || lower.contains('flood')) keywords.add('flood hazard');
    if (lower.contains('victim')) keywords.add('casualties');
    return keywords.isEmpty ? 'general field assessment' : keywords.join(', ');
  }
}
