import 'dart:convert';
import 'package:flutter/material.dart';

enum UrgencyLevel { red, yellow, green }

class TriageResult {
  final UrgencyLevel urgency;
  final String summary;
  final List<String> steps;
  final String? evacuationRoute;
  final DateTime timestamp;
  final bool isExpertMode;
  final Map<String, dynamic>? rawJson;

  TriageResult({
    required this.urgency,
    required this.summary,
    required this.steps,
    this.evacuationRoute,
    required this.timestamp,
    this.isExpertMode = false,
    this.rawJson,
  });

  factory TriageResult.fromLocalJson(Map<String, dynamic> json) {
    return TriageResult(
      urgency: _parseUrgency(json['urgency'] ?? 'green'),
      summary: json['summary'] ?? 'No summary available',
      steps: _parseSteps(json['steps']),
      evacuationRoute: json['evacuation_route'],
      timestamp: DateTime.now(),
      isExpertMode: false,
      rawJson: json,
    );
  }

  /// Parses raw LLM text (handling markdown code blocks and raw JSON)
  factory TriageResult.fromRawLlmResponse(String rawText, {required double latencyMs, String modelName = 'gemma-4-edge'}) {
    Map<String, dynamic>? parsedJson;
    try {
      // 1. Try direct JSON parse
      parsedJson = jsonDecode(rawText.trim()) as Map<String, dynamic>;
    } catch (_) {
      // 2. Extract JSON from markdown backticks or braces
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawText);
      if (jsonMatch != null) {
        try {
          parsedJson = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    if (parsedJson != null) {
      final urgencyStr = parsedJson['urgency'] ?? parsedJson['urgency_level'] ?? 'green';
      final summaryStr = parsedJson['summary'] ?? parsedJson['clinical_summary'] ?? 'Local triage completed via Gemma edge model.';
      final rawSteps = parsedJson['steps'] ?? parsedJson['first_aid_steps'];
      final evac = parsedJson['evacuation_route'] ?? parsedJson['evacuation_target'];

      return TriageResult(
        urgency: _parseUrgency(urgencyStr.toString()),
        summary: summaryStr.toString(),
        steps: _parseSteps(rawSteps),
        evacuationRoute: evac?.toString(),
        timestamp: DateTime.now(),
        isExpertMode: false,
        rawJson: {
          ...parsedJson,
          'latency_ms': latencyMs,
          'model': modelName,
        },
      );
    }

    // Fallback if LLM output was non-JSON plain text
    final urgency = _parseUrgencyFromText(rawText);
    return TriageResult(
      urgency: urgency,
      summary: rawText.length > 250 ? '${rawText.substring(0, 250)}...' : rawText,
      steps: _extractStepsFromText(rawText),
      timestamp: DateTime.now(),
      isExpertMode: false,
      rawJson: {
        'raw_response': rawText,
        'latency_ms': latencyMs,
        'model': modelName,
      },
    );
  }

  static List<String> _parseSteps(dynamic rawSteps) {
    if (rawSteps == null) return [];
    if (rawSteps is List) {
      return rawSteps
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (rawSteps is String) {
      return _extractStepsFromText(rawSteps);
    }
    return [rawSteps.toString()];
  }

  static UrgencyLevel _parseUrgencyFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('red') || lower.contains('critical') || lower.contains('severe') || lower.contains('emergency')) {
      return UrgencyLevel.red;
    }
    if (lower.contains('yellow') || lower.contains('urgent') || lower.contains('moderate')) {
      return UrgencyLevel.yellow;
    }
    return UrgencyLevel.green;
  }

  static List<String> _extractStepsFromText(String text) {
    final lines = text.split('\n');
    final steps = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^(\d+[\.\)]|\-|\*)\s+').hasMatch(trimmed)) {
        steps.add(trimmed.replaceFirst(RegExp(r'^(\d+[\.\)]|\-|\*)\s+'), ''));
      }
    }
    return steps.isNotEmpty ? steps : ['Follow standard first-aid protocols', 'Assess scene safety', 'Monitor victim vitals'];
  }

  factory TriageResult.fromExpertResponse(Map<String, dynamic> json) {
    return TriageResult(
      urgency: _parseUrgency(json['urgency_level'] ?? json['urgency'] ?? 'green'),
      summary: json['clinical_summary'] ?? json['summary'] ?? 'No summary',
      steps: _parseSteps(json['first_aid_steps'] ?? json['steps']),
      evacuationRoute: json['evacuation_target'] ?? json['evacuation_route'],
      timestamp: DateTime.now(),
      isExpertMode: true,
      rawJson: json,
    );
  }

  static UrgencyLevel _parseUrgency(String value) {
    switch (value.toLowerCase()) {
      case 'red':
      case 'critical':
      case 'emergency':
        return UrgencyLevel.red;
      case 'yellow':
      case 'urgent':
      case 'moderate':
        return UrgencyLevel.yellow;
      default:
        return UrgencyLevel.green;
    }
  }

  Color get urgencyColor {
    switch (urgency) {
      case UrgencyLevel.red:
        return const Color(0xFFB71C1C);
      case UrgencyLevel.yellow:
        return const Color(0xFFF57F17);
      case UrgencyLevel.green:
        return const Color(0xFF1B5E20);
    }
  }

  String get urgencyLabel {
    switch (urgency) {
      case UrgencyLevel.red:
        return 'CRITICAL';
      case UrgencyLevel.yellow:
        return 'URGENT';
      case UrgencyLevel.green:
        return 'STABLE';
    }
  }

  Map<String, dynamic> toJson() => {
    'urgency': urgency.name,
    'summary': summary,
    'steps': steps,
    'evacuation_route': evacuationRoute,
    'timestamp': timestamp.toIso8601String(),
    'is_expert_mode': isExpertMode,
  };
}

class FieldPayload {
  final String? imageBase64;
  final String? audioTranscript;
  final String textQuery;
  final String? sectorId;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  FieldPayload({
    this.imageBase64,
    this.audioTranscript,
    required this.textQuery,
    this.sectorId,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'image_base64': imageBase64,
    'audio_transcript': audioTranscript,
    'text_query': textQuery,
    'sector_id': sectorId,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
  };
}
