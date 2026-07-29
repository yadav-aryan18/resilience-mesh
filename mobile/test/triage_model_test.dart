import 'package:flutter_test/flutter_test.dart';
import 'package:resiliencemesh/models/triage_model.dart';

void main() {
  group('TriageResult Model Tests', () {
    test('fromLocalJson parses valid JSON data correctly', () {
      final json = {
        'urgency': 'red',
        'summary': 'Critical victim bleeding profusely',
        'steps': ['Apply direct pressure', 'Elevate legs'],
        'evacuation_route': 'Sector 4 Evac Point A',
      };

      final result = TriageResult.fromLocalJson(json);
      expect(result.urgency, UrgencyLevel.red);
      expect(result.urgencyLabel, 'CRITICAL');
      expect(result.summary, 'Critical victim bleeding profusely');
      expect(result.steps.length, 2);
      expect(result.evacuationRoute, 'Sector 4 Evac Point A');
      expect(result.isExpertMode, isFalse);
    });

    test('fromRawLlmResponse parses embedded JSON response correctly', () {
      const rawResponse = '''
      ```json
      {
        "urgency": "yellow",
        "summary": "Moderate leg fracture detected",
        "steps": ["Apply rigid splint", "Clean wound"],
        "evacuation_route": "Sector 2 Safe Zone"
      }
      ```
      ''';

      final result = TriageResult.fromRawLlmResponse(
        rawResponse,
        latencyMs: 150.0,
        modelName: 'gemma-4-edge',
      );

      expect(result.urgency, UrgencyLevel.yellow);
      expect(result.urgencyLabel, 'URGENT');
      expect(result.summary, 'Moderate leg fracture detected');
      expect(result.steps.length, 2);
      expect(result.evacuationRoute, 'Sector 2 Safe Zone');
    });

    test('fromExpertResponse parses expert server response correctly', () {
      final expertJson = {
        'urgency_level': 'red',
        'clinical_summary': 'Hemorrhagic shock risk high',
        'first_aid_steps': ['Apply tourniquet 2 inches above wound', 'Keep victim warm'],
        'evacuation_target': 'Command MedEvac Site 1',
      };

      final result = TriageResult.fromExpertResponse(expertJson);
      expect(result.urgency, UrgencyLevel.red);
      expect(result.summary, 'Hemorrhagic shock risk high');
      expect(result.steps.length, 2);
      expect(result.isExpertMode, isTrue);
    });
  });
}
