import 'dart:convert';
import 'dart:io';

/// Debug-session telemetry for OTA (session 0b9d45). Do not log secrets.
void otaDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
}) {
  // #region agent log
  try {
    final payload = jsonEncode({
      'sessionId': '0b9d45',
      'runId': 'pre-fix',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    try {
      File(
        '/Users/bastianabarca/CODE/project_transworld-nexus/projects/transworld-nexus/.cursor/debug-0b9d45.log',
      ).writeAsStringSync('$payload\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    () async {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 800);
        final req = await client.postUrl(
          Uri.parse(
            'http://127.0.0.1:7305/ingest/02f03f94-db5d-49ad-bd74-d663fc657326',
          ),
        );
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('X-Debug-Session-Id', '0b9d45');
        req.add(utf8.encode(payload));
        await req.close().timeout(const Duration(milliseconds: 800));
        client.close(force: true);
      } catch (_) {}
    }();
  } catch (_) {}
  // #endregion
}
