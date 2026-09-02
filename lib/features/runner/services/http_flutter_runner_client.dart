import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../workspace/models/workspace_change.dart';
import '../models/run_session.dart';
import '../models/runner_event.dart';
import 'flutter_runner_client.dart';

class HttpFlutterRunnerClient implements FlutterRunnerClient {
  HttpFlutterRunnerClient({
    required String baseUrl,
    http.Client? httpClient,
    this.pollInterval = const Duration(milliseconds: 350),
  })  : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration pollInterval;
  final http.Client _http;
  final Set<String> _disposedSessions = <String>{};

  @override
  String get displayName => 'Flutter SDK Runner';

  @override
  bool get isMock => false;

  @override
  Future<RunSession> createSession({
    required Map<String, String> files,
  }) async {
    final response = await _http.post(
      _uri('/sessions'),
      headers: _jsonHeaders,
      body: jsonEncode({'files': files}),
    );
    final body = _decodeObject(response, expected: const {200, 201});
    return RunSession.fromJson(
      Map<String, dynamic>.from(body['session'] as Map),
    );
  }

  @override
  Stream<RunnerEvent> watchSession(String sessionId) async* {
    var logCursor = 0;
    RunnerStatus? lastStatus;
    String? lastPreviewUrl;

    while (!_disposedSessions.contains(sessionId)) {
      final response = await _http.get(
        _uri('/sessions/$sessionId', {'afterLog': '$logCursor'}),
      );

      if (_disposedSessions.contains(sessionId)) return;
      final body = _decodeObject(response);
      final session = RunSession.fromJson(
        Map<String, dynamic>.from(body['session'] as Map),
      );

      if (session.status != lastStatus ||
          session.previewUrl != lastPreviewUrl) {
        lastStatus = session.status;
        lastPreviewUrl = session.previewUrl;
        yield RunnerEvent.session(session);
      }

      final logs = body['logs'];
      if (logs is List) {
        for (final raw in logs) {
          if (raw is! Map) continue;
          final message = raw['message'];
          final index = raw['index'];
          if (message is String) {
            yield RunnerEvent.log(message);
          }
          if (index is num && index.toInt() >= logCursor) {
            logCursor = index.toInt() + 1;
          }
        }
      }

      final nextLogIndex = body['nextLogIndex'];
      if (nextLogIndex is num && nextLogIndex.toInt() > logCursor) {
        logCursor = nextLogIndex.toInt();
      }

      await Future<void>.delayed(pollInterval);
    }
  }

  @override
  Future<void> syncWorkspace({
    required String sessionId,
    required Map<String, String> files,
    required List<WorkspaceChange> changes,
  }) async {
    final response = await _http.put(
      _uri('/sessions/$sessionId/workspace'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'files': files,
        'changes': changes
            .map(
              (change) => {
                'type': change.type.name,
                'path': change.path,
                if (change.previousPath != null)
                  'previousPath': change.previousPath,
              },
            )
            .toList(growable: false),
      }),
    );
    _decodeObject(response);
  }

  @override
  Future<void> run(String sessionId) => _postAction(sessionId, 'run');

  @override
  Future<void> hotReload(String sessionId) =>
      _postAction(sessionId, 'hot-reload');

  @override
  Future<void> hotRestart(String sessionId) =>
      _postAction(sessionId, 'hot-restart');

  @override
  Future<void> stop(String sessionId) => _postAction(sessionId, 'stop');

  @override
  Future<void> disposeSession(String sessionId) async {
    _disposedSessions.add(sessionId);
    final response = await _http.delete(_uri('/sessions/$sessionId'));
    if (response.statusCode != 404) {
      _decodeObject(response, expected: const {200, 204});
    }
  }

  Future<void> _postAction(String sessionId, String action) async {
    final response = await _http.post(
      _uri('/sessions/$sessionId/$action'),
      headers: _jsonHeaders,
    );
    _decodeObject(response, expected: const {200, 202});
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeObject(
    http.Response response, {
    Set<int> expected = const {200},
  }) {
    if (!expected.contains(response.statusCode)) {
      var detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is String) {
          detail = decoded['error'] as String;
        }
      } catch (_) {
        // Keep the raw response body when it is not JSON.
      }
      throw RunnerHttpException(response.statusCode, detail);
    }

    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Runner response must be a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static const _jsonHeaders = <String, String>{
    'content-type': 'application/json',
    'accept': 'application/json',
  };
}

class RunnerHttpException implements Exception {
  const RunnerHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Runner HTTP $statusCode: $message';
}
