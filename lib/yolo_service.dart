import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;


class YoloService {
  /// Detection server URL (including scheme and port). Default is localhost.
  late final Uri endpoint;

  /// [server] should be your Railway public URL after deployment,
  /// e.g. 'https://campusfix-ai.up.railway.app'
  /// Replace the value below with your actual Render domain.
  YoloService({String server = 'https://spotit2.onrender.com'}) {
    var s = server.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    endpoint = Uri.parse('$s/detect');
  }
  Future<void> loadModel() async {
    // no-op for HTTP-backed model; kept for compatibility
    return;
  }

  /// Sends an image file at [path] to the detection server and returns the
  /// parsed JSON response as a map. If an error occurs, an empty map is
  /// returned.
  Future<Map<String, dynamic>> detectFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return {};

    try {
      print('YoloService: sending file $path to $endpoint');

      // quick reachability check to help debug network issues
      final base = Uri.parse('${endpoint.scheme}://${endpoint.authority}/');
      try {
        final ping = await http.get(base).timeout(const Duration(seconds: 3));
        print('Server reachability check: ${base} -> ${ping.statusCode}');
      } catch (e) {
        print('Server reachability check failed: $e');
      }

      final req = http.MultipartRequest('POST', endpoint);
      req.files.add(await http.MultipartFile.fromPath('file', path));

      // add a timeout so we fail fast and can surface a clearer message
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) {
          // Normalize to expected shape: ensure `detections` key exists
          final rawDets = (decoded['detections'] is List) ? List.from(decoded['detections']) : [];
          // Normalize each detection to ensure keys exist and types are correct
          final dets = <Map<String, dynamic>>[];
          for (var item in rawDets) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item as Map);
            // label fallback order
            String label = '';
            if (m.containsKey('label') && m['label'] != null) {
              label = '${m['label']}';
            } else if (m.containsKey('class') && m['class'] != null) {
              label = '${m['class']}';
            } else if (m.containsKey('name') && m['name'] != null) {
              label = '${m['name']}';
            } else if (m.containsKey('class_name') && m['class_name'] != null) {
              label = '${m['class_name']}';
            } else if (m.containsKey('class_id') && m['class_id'] != null) {
              label = '${m['class_id']}';
            } else {
              label = 'Unknown';
            }

            // score normalization
            double score = 0.0;
            if (m.containsKey('score')) {
              final s = m['score'];
              if (s is num) score = s.toDouble();
              else score = double.tryParse('$s') ?? 0.0;
            } else if (m.containsKey('conf')) {
              final s = m['conf'];
              if (s is num) score = s.toDouble();
              else score = double.tryParse('$s') ?? 0.0;
            }

            // box normalization: expects [x1,y1,x2,y2]
            List<double> box = [];
            if (m.containsKey('box') && m['box'] is List) {
              try {
                box = List.from(m['box']).map<double>((e) => (e is num) ? e.toDouble() : double.tryParse('$e') ?? 0.0).toList();
              } catch (_) {
                box = [];
              }
            }

            final classId = m.containsKey('class_id')
                ? ((m['class_id'] is num) ? (m['class_id'] as num).toInt() : int.tryParse('${m['class_id']}') ?? 0)
                : (m.containsKey('class') && m['class'] is num ? (m['class'] as num).toInt() : null);

            dets.add({
              'label': label,
              'class': label,
              'score': score,
              'box': box,
              'class_id': classId,
              ...m,
            });
          }
          // compute summary fields for backward compatibility
          String topLabel = 'Unknown';
          double topScore = 0.0;
          if (dets.isNotEmpty) {
            dets.sort((a, b) => (b['score'] as num).toDouble().compareTo((a['score'] as num).toDouble()));
            final top = dets.first;
            topLabel = '${top['class'] ?? top['label'] ?? 'Unknown'}';
            topScore = (top['score'] ?? 0.0) is num ? (top['score'] as num).toDouble() : double.tryParse('${top['score']}') ?? 0.0;
          }
          final severity = (topScore >= 0.8) ? 'High' : (topScore >= 0.5 ? 'Medium' : 'Low');
          return {
            'class': decoded['class'] ?? topLabel,
            'confidence': decoded['confidence'] ?? topScore,
            'severity': decoded['severity'] ?? severity,
            'predictions': decoded['predictions'] ?? [],
            'detections': dets,
          };
        }
        return {'result': decoded};
      } else {
        print('Detection server responded ${resp.statusCode}: ${resp.body}');
        return {};
      }
    } catch (e) {
      print('detectFromFile error: $e');
      return {};
    }
  }
}

