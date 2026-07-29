import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/triage_model.dart';

/// Service for persisting offline field triage reports across app restarts
class HistoryService {
  static const String _keyHistory = 'field_triage_history_v1';
  static const int _maxEntries = 50;

  /// Save a new triage result to local storage
  Future<void> saveResult(TriageResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();

      // Prepend new result
      history.insert(0, result);

      // Limit entries to maxEntries
      final trimmed = history.take(_maxEntries).toList();
      final jsonList = trimmed.map((e) => jsonEncode(e.toJson())).toList();

      await prefs.setStringList(_keyHistory, jsonList);
    } catch (e) {
      debugPrint('Failed to save triage result to local history: $e');
    }
  }

  /// Retrieve all stored triage history reports
  Future<List<TriageResult>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyHistory) ?? [];

      final results = <TriageResult>[];
      for (final jsonStr in jsonList) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonStr);
          results.add(TriageResult.fromLocalJson(data));
        } catch (_) {}
      }
      return results;
    } catch (e) {
      debugPrint('Failed to load triage history: $e');
      return [];
    }
  }

  /// Clear all stored triage history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHistory);
    } catch (e) {
      debugPrint('Failed to clear triage history: $e');
    }
  }
}
