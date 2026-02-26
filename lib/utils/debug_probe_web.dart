import 'dart:convert';
import 'dart:html' as html;

const String _debugEndpoint = 'http://127.0.0.1:7242/ingest/0b08f48a-7e8e-4af4-b71c-74a5e824b60e';

Future<void> debugProbeLog({
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?>? data,
}) async {
  final payload = <String, Object?>{
    'id': 'log_${DateTime.now().millisecondsSinceEpoch}_${hypothesisId}',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data ?? const <String, Object?>{},
  };
  try {
    await html.HttpRequest.request(
      _debugEndpoint,
      method: 'POST',
      sendData: jsonEncode(payload),
      requestHeaders: const {'Content-Type': 'application/json'},
    );
  } catch (_) {}
}
