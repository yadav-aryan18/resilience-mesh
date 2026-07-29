import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/triage_model.dart';

/// Mesh client for Tier 2 Laptop Command Node communication
/// Uses local Wi-Fi Direct / hotspot (completely air-gapped)
class MeshClientService {
  String _baseUrl = 'http://192.168.49.1:8000'; // Default hotspot gateway
  final Duration _timeout = const Duration(seconds: 30);

  String get baseUrl => _baseUrl;

  void setLaptopIp(String ip) {
    String cleanIp = ip.trim().replaceAll('http://', '').replaceAll('https://', '');
    if (cleanIp.contains(':')) {
      cleanIp = cleanIp.split(':').first;
    }
    if (cleanIp.endsWith('/')) {
      cleanIp = cleanIp.substring(0, cleanIp.length - 1);
    }
    _baseUrl = 'http://$cleanIp:8000';
  }

  Future<bool> isLaptopReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Automatically scan common local gateways and subnets for an active Command Node
  Future<String?> discoverLaptopNode() async {
    final candidateIps = [
      '192.168.49.1',  // Wi-Fi Direct gateway
      '192.168.43.1',  // Mobile hotspot gateway
      '10.42.0.1',     // Linux NetworkManager AP
      '192.168.1.1',   // Standard LAN gateway
      '192.168.0.1',   // Alternative LAN gateway
      '10.0.0.1',      // Class A LAN gateway
      '10.0.2.2',      // Android Emulator host
      'localhost',     // Local loopback
      '127.0.0.1',
    ];

    // First check current set IP
    if (await isLaptopReachable()) {
      return _baseUrl.replaceAll('http://', '').replaceAll(':8000', '');
    }

    // Ping candidates concurrently with 1.5s timeout
    final completer = Completer<String?>();
    int pendingCount = candidateIps.length;

    for (final ip in candidateIps) {
      http
          .get(Uri.parse('http://$ip:8000/api/health'))
          .timeout(const Duration(milliseconds: 1500))
          .then((response) {
        if (response.statusCode == 200 && !completer.isCompleted) {
          setLaptopIp(ip);
          completer.complete(ip);
        }
      }).catchError((_) {}).whenComplete(() {
        pendingCount--;
        if (pendingCount == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  /// Transmit payload to laptop and stream back expert triage
  Future<TriageResult> requestExpertTriage(FieldPayload payload) async {
    final uri = Uri.parse('$_baseUrl/api/expert-triage');

    final request = http.MultipartRequest('POST', uri)
      ..fields['payload'] = jsonEncode(payload.toJson());

    if (payload.imageBase64 != null && payload.imageBase64!.isNotEmpty) {
      request.fields['image_base64'] = payload.imageBase64!;
    }

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Expert node error: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TriageResult.fromExpertResponse(json);
  }

  /// Check if internet is available (for opportunistic web agent)
  Future<bool> hasInternet() async {
    final dynamic connResult = await Connectivity().checkConnectivity();
    final bool isDisconnected = (connResult is List)
        ? connResult.contains(ConnectivityResult.none)
        : connResult == ConnectivityResult.none;

    if (isDisconnected) return false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
