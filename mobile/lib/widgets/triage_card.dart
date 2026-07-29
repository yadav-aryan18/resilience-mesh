import 'package:flutter/material.dart';
import '../models/triage_model.dart';

class TriageCard extends StatelessWidget {
  final TriageResult result;

  const TriageCard({super.key, required this.result});

  IconData get _urgencyIcon {
    switch (result.urgency) {
      case UrgencyLevel.red:
        return Icons.warning_amber_rounded;
      case UrgencyLevel.yellow:
        return Icons.error_outline_rounded;
      case UrgencyLevel.green:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? latencyMs = result.rawJson != null && result.rawJson!['latency_ms'] != null
        ? (result.rawJson!['latency_ms'] as num).toDouble()
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            result.urgencyColor.withOpacity(0.35),
            result.urgencyColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: result.urgencyColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: result.urgencyColor.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: result.urgencyColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_urgencyIcon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      result.urgencyLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (latencyMs != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${latencyMs.toStringAsFixed(0)}ms',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (result.isExpertMode ? const Color(0xFF1565C0) : const Color(0xFF1B5E20)).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: result.isExpertMode ? const Color(0xFF1565C0) : const Color(0xFF1B5E20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.isExpertMode ? Icons.laptop_mac : Icons.memory,
                      color: result.isExpertMode ? const Color(0xFF1565C0) : const Color(0xFF81C784),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result.isExpertMode ? 'EXPERT 12B' : 'EDGE GEMMA',
                      style: TextStyle(
                        color: result.isExpertMode ? const Color(0xFF1565C0) : const Color(0xFF81C784),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
