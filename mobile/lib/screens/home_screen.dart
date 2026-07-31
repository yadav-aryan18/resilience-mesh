import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';
import '../services/local_inference_service.dart';
import '../services/mesh_client_service.dart';
import '../services/audio_service.dart';
import '../services/camera_service.dart';
import '../services/history_service.dart';
import '../models/triage_model.dart';
import 'triage_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _sectorController = TextEditingController();
  final _ipController = TextEditingController(text: '192.168.49.1');

  final _localInference = LocalInferenceService();
  final _meshClient = MeshClientService();
  final _audioService = AudioService();
  final _cameraService = CameraService();
  final _historyService = HistoryService();

  bool _expertMode = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isLoadingModel = false;
  bool _isDiscoveringNode = false;
  String? _capturedImageBase64;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    logger.init();
    _initModel();
  }

  Future<void> _initModel({String? customPath}) async {
    setState(() => _isLoadingModel = true);
    await _localInference.loadModel(customModelPath: customPath);
    if (mounted) {
      setState(() => _isLoadingModel = false);
    }
  }

  Future<void> _autoDiscoverMeshNode() async {
    setState(() => _isDiscoveringNode = true);
    try {
      final discoveredIp = await _meshClient.discoverLaptopNode();
      if (mounted) {
        if (discoveredIp != null) {
          _ipController.text = discoveredIp;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Discovered Command Node at $discoveredIp'),
              backgroundColor: const Color(0xFF1B5E20),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No Command Node found on local mesh. Check hotspot connection.'),
              backgroundColor: Color(0xFFF57F17),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isDiscoveringNode = false);
    }
  }

  Future<void> _pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin', 'task', 'tflite', 'gguf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _initModel(customPath: path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected Gemma model: ${path.split('/').last}'),
              backgroundColor: const Color(0xFF1B5E20),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick model file: $e'),
            backgroundColor: const Color(0xFFB71C1C),
          ),
        );
      }
    }
  }

  void _showHistoryModal() async {
    final history = await _historyService.getHistory();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mission Triage History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await _historyService.clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No saved mission triage records.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: item.urgencyColor.withOpacity(0.2),
                          child: Icon(Icons.emergency, color: item.urgencyColor, size: 20),
                        ),
                        title: Text(
                          item.summary,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.urgencyLabel} • ${item.timestamp.toLocal().toString().split('.').first}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TriageScreen(result: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDebugLogDumpModal() async {
    final logText = await logger.getLogDump();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📋 System Debug Log Dump',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 20),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: logText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logs copied to clipboard!')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Clear Logs',
                        onPressed: () async {
                          await logger.clearLogs();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    logText.isEmpty ? 'No system log entries recorded yet.' : logText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ResilienceMesh',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Tactical Field Response Node',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _showDebugLogDumpModal,
                          icon: const Icon(Icons.terminal, color: Colors.amberAccent),
                          tooltip: 'System Debug Log Dump',
                        ),
                        IconButton(
                          onPressed: _showHistoryModal,
                          icon: const Icon(Icons.history, color: Colors.white70),
                          tooltip: 'Mission History Logs',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Expert Mode Toggle
                    _buildExpertToggle(theme),
                  ],
                ),
              ),
            ),

            // Input Form
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Sector ID
                    TextField(
                      controller: _sectorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Sector ID (e.g., Sector 4)'),
                    ),
                    const SizedBox(height: 12),
                    // Text Query
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Describe situation...',
                        hint: '2 victims, severe leg bleeding, water rising',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Media Controls
                    Row(
                      children: [
                        _buildMediaButton(
                          icon: Icons.camera_alt,
                          label: 'Photo',
                          onTap: _capturePhoto,
                          isActive: _capturedImageBase64 != null,
                        ),
                        const SizedBox(width: 12),
                        _buildMediaButton(
                          icon: _isRecording ? Icons.stop : Icons.mic,
                          label: _isRecording ? 'Stop' : 'Voice',
                          onTap: _toggleRecording,
                          isActive: _isRecording,
                          color: _isRecording ? Colors.red : null,
                        ),
                        const SizedBox(width: 12),
                        if (_capturedImageBase64 != null)
                          _buildMediaButton(
                            icon: Icons.clear,
                            label: 'Clear',
                            onTap: () => setState(() => _capturedImageBase64 = null),
                            color: Colors.grey,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _submitTriage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _expertMode
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _expertMode ? 'REQUEST EXPERT TRIAGE' : 'RUN LOCAL TRIAGE',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status / Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildStatusCard(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpertToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expertMode ? const Color(0xFF1565C0) : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _expertMode ? Icons.laptop_mac : Icons.phone_android,
                color: _expertMode ? const Color(0xFF1565C0) : const Color(0xFF1B5E20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expert Mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _expertMode
                          ? 'Transmit to laptop command node'
                          : 'On-device Gemma 4 E4B/E2B inference engine',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _expertMode,
                onChanged: (v) {
                  setState(() => _expertMode = v);
                  if (v) _autoDiscoverMeshNode();
                },
                activeColor: const Color(0xFF1565C0),
              ),
            ],
          ),
          if (_expertMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration('Laptop IP Address'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _isDiscoveringNode ? null : _autoDiscoverMeshNode,
                  icon: _isDiscoveringNode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar, size: 20),
                  tooltip: 'Auto-scan mesh for Command Node',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? (color ?? const Color(0xFF1B5E20)).withOpacity(0.2)
                : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? (color ?? const Color(0xFF1B5E20))
                  : Colors.white10,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color ?? Colors.white70, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color ?? Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final modelName = _localInference.activeModelName;
    final isLoaded = _localInference.isReady;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Status',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _pickModelFile,
                icon: const Icon(Icons.folder_open, color: Colors.blueAccent, size: 20),
                tooltip: 'Select Gemma Model File (.bin/.task)',
              ),
            ],
          ),
          const SizedBox(height: 6),
          _statusRow(
            'Edge Model',
            modelName,
            _isLoadingModel ? 'Loading...' : (isLoaded ? 'Ready' : 'Heuristic Mode'),
            _isLoadingModel ? Colors.orange : (isLoaded ? const Color(0xFF1B5E20) : Colors.amber),
          ),
          const SizedBox(height: 8),
          _statusRow('Network', 'Air-Gapped Mesh', 'Wi-Fi Direct', const Color(0xFFF57F17)),
          const SizedBox(height: 8),
          _statusRow('Location', 'GPS / Manual', 'Sector Input', Colors.blue),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, String status, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: const Color(0xFF161B22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    HapticFeedback.mediumImpact();
    final b64 = await _cameraService.capturePhoto();
    if (b64 != null) setState(() => _capturedImageBase64 = b64);
  }

  Future<void> _toggleRecording() async {
    HapticFeedback.mediumImpact();
    if (_isRecording) {
      final path = await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _submitTriage() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      TriageResult result;

      if (_expertMode) {
        _meshClient.setLaptopIp(_ipController.text.trim());
        var reachable = await _meshClient.isLaptopReachable();
        if (!reachable) {
          final discoveredIp = await _meshClient.discoverLaptopNode();
          if (discoveredIp != null) {
            _ipController.text = discoveredIp;
            reachable = true;
          }
        }

        if (!reachable) {
          throw Exception('Laptop command node unreachable at ${_ipController.text}. Check Wi-Fi connection.');
        }

        final payload = FieldPayload(
          imageBase64: _capturedImageBase64,
          audioTranscript: _audioPath != null ? await _audioService.transcribe(_audioPath!) : null,
          textQuery: _textController.text.trim(),
          sectorId: _sectorController.text.trim().isEmpty ? null : _sectorController.text.trim(),
          timestamp: DateTime.now(),
        );

        result = await _meshClient.requestExpertTriage(payload);
      } else {
        result = await _localInference.infer(
          imageBytes: _capturedImageBase64 != null ? base64Decode(_capturedImageBase64!) : null,
          audioTranscript: _audioPath != null ? await _audioService.transcribe(_audioPath!) : null,
          textQuery: _textController.text.trim(),
        );
      }

      // Persist to local mission triage history
      await _historyService.saveResult(result);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TriageScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFB71C1C),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _sectorController.dispose();
    _ipController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
