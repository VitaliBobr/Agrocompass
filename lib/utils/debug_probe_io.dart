import 'dart:convert';
import 'dart:io';

const String _debugLogPath = r'd:\Agrokilar\.cursor\debug.log';

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
    final f = File(_debugLogPath);
    await f.writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
