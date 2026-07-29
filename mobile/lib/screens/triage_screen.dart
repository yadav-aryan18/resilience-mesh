import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/triage_model.dart';
import '../services/tts_service.dart';
import '../widgets/triage_card.dart';

class TriageScreen extends StatefulWidget {
  final TriageResult result;

  const TriageScreen({super.key, required this.result});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _ttsService = TtsService();
  bool _isPlayingAudio = false;

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _toggleTts() async {
    HapticFeedback.mediumImpact();
    if (_isPlayingAudio) {
      await _ttsService.stop();
      setState(() => _isPlayingAudio = false);
    } else {
      setState(() => _isPlayingAudio = true);
      await _ttsService.speakTriage(widget.result);
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _speakSingleStep(int stepIndex, String text) async {
    HapticFeedback.lightImpact();
    setState(() => _isPlayingAudio = true);
    await _ttsService.speakStep(stepIndex, text);
    if (mounted) setState(() => _isPlayingAudio = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          result.isExpertMode ? 'Expert Triage Report' : 'Local Triage Report',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _ttsService.stop();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            onPressed: _toggleTts,
            icon: Icon(
              _isPlayingAudio ? Icons.volume_up : Icons.volume_off_outlined,
              color: _isPlayingAudio ? Colors.greenAccent : Colors.white70,
            ),
            tooltip: _isPlayingAudio ? 'Stop Speech Readout' : 'Read Protocol Aloud',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency Banner
            TriageCard(result: result),
            const SizedBox(height: 20),

            // Clinical Steps Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FIRST-AID PROTOCOL',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleTts,
                  icon: Icon(
                    _isPlayingAudio ? Icons.stop_circle : Icons.play_circle_fill,
                    size: 18,
                    color: _isPlayingAudio ? Colors.redAccent : const Color(0xFF1B5E20),
                  ),
                  label: Text(
                    _isPlayingAudio ? 'STOP VOICE' : 'READ ALOUD',
                    style: TextStyle(
                      color: _isPlayingAudio ? Colors.redAccent : const Color(0xFF1B5E20),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...result.steps.asMap().entries.map((entry) {
              return _buildStepCard(entry.key, entry.value, theme);
            }),

            // Evacuation
            if (result.evacuationRoute != null && result.evacuationRoute!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'EVACUATION & LOGISTICS',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1565C0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_run, color: Color(0xFF1565C0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.evacuationRoute!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Metadata
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metaRow('Timestamp', result.timestamp.toLocal().toString().split('.').first),
                  const Divider(color: Colors.white10, height: 12),
                  _metaRow('Mode', result.isExpertMode ? 'Expert Command Node' : 'On-Device Edge Model'),
                  const Divider(color: Colors.white10, height: 12),
                  _metaRow('Network', result.isExpertMode ? 'Mesh Wi-Fi' : 'Air-Gapped Offline'),
                  if (result.rawJson != null && result.rawJson!['latency_ms'] != null) ...[
                    const Divider(color: Colors.white10, height: 12),
                    _metaRow('Inference Latency', '${(result.rawJson!['latency_ms'] as num).toStringAsFixed(1)} ms'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int stepIndex, String text, ThemeData theme) {
    final result = widget.result;
    final stepNum = stepIndex + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: result.urgencyColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNum',
                style: TextStyle(
                  color: result.urgencyColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            ),
          ),
          IconButton(
            onPressed: () => _speakSingleStep(stepIndex, text),
            icon: const Icon(Icons.volume_up, color: Colors.white38, size: 20),
            tooltip: 'Read Step $stepNum',
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
