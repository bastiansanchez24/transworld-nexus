import 'dart:convert';
import 'dart:io';

/// Debug-session telemetry for OTA (session 23a43f). Do not log secrets.
void otaDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  // #region agent log
  try {
    final payload = jsonEncode({
      'sessionId': '23a43f',
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    for (final path in _logFiles) {
      try {
        File(
          path,
        ).writeAsStringSync('$payload\n', mode: FileMode.append, flush: true);
      } catch (_) {}
    }
    () async {
      for (final url in _ingestUrls) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(milliseconds: 800);
          final req = await client.postUrl(Uri.parse(url));
          req.headers.set('Content-Type', 'application/json');
          req.headers.set('X-Debug-Session-Id', '23a43f');
          req.add(utf8.encode(payload));
          await req.close().timeout(const Duration(milliseconds: 800));
          client.close(force: true);
        } catch (_) {}
      }
    }();
  } catch (_) {}
  // #endregion
}

const _ingestUrls = [
  'http://127.0.0.1:7917/ingest/9fa0e09b-80df-4c81-86c4-f4966a429947',
  'http://10.0.2.2:7917/ingest/9fa0e09b-80df-4c81-86c4-f4966a429947',
];

List<String> get _logFiles {
  final files = <String>[
    r'c:\src\CODE\project_transworld-nexus\projects\transworld-nexus\debug-23a43f.log',
  ];
  try {
    files.add(
      '${Directory.systemTemp.path}${Platform.pathSeparator}debug-23a43f.log',
    );
  } catch (_) {}
  return files;
}
