import 'dart:convert';
import 'dart:io';

import 'runner_session.dart';
import 'session_manager.dart';

class RunnerServer {
  RunnerServer({
    required this.manager,
    this.allowedOrigin = '*',
  });

  final SessionManager manager;
  final String allowedOrigin;

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      await _sendEmpty(request.response, HttpStatus.noContent);
      return;
    }

    try {
      final segments = request.uri.pathSegments;

      if (request.method == 'GET' &&
          segments.length == 1 &&
          segments.first == 'health') {
        await _sendJson(
          request.response,
          HttpStatus.ok,
          {
            'status': 'ok',
            'activeSessions': manager.sessions.length,
          },
        );
        return;
      }

      if (segments.isEmpty || segments.first != 'sessions') {
        await _sendError(
          request.response,
          HttpStatus.notFound,
          'Route not found.',
        );
        return;
      }

      if (segments.length == 1 && request.method == 'POST') {
        final body = await _readJsonObject(request);
        final files = _readFiles(body['files']);
        final session = await manager.createSession(files);
        await _sendJson(
          request.response,
          HttpStatus.created,
          {'session': session.toJson()},
        );
        return;
      }

      if (segments.length < 2) {
        await _sendError(
          request.response,
          HttpStatus.notFound,
          'Route not found.',
        );
        return;
      }

      final sessionId = segments[1];

      if (segments.length == 2 && request.method == 'GET') {
        final session = manager.requireSession(sessionId);
        final afterLog = int.tryParse(
              request.uri.queryParameters['afterLog'] ?? '0',
            ) ??
            0;
        final safeCursor = afterLog.clamp(0, session.logs.length).toInt();
        final logs = session.logs
            .skip(safeCursor)
            .map((entry) => entry.toJson())
            .toList(growable: false);

        await _sendJson(
          request.response,
          HttpStatus.ok,
          {
            'session': session.toJson(),
            'logs': logs,
            'nextLogIndex': session.logs.length,
          },
        );
        return;
      }

      if (segments.length == 2 && request.method == 'DELETE') {
        manager.requireSession(sessionId);
        await manager.disposeSession(sessionId);
        await _sendEmpty(request.response, HttpStatus.noContent);
        return;
      }

      if (segments.length == 3 &&
          segments[2] == 'workspace' &&
          request.method == 'PUT') {
        final session = manager.requireSession(sessionId);
        final body = await _readJsonObject(request);
        final files = _readFiles(body['files']);
        await manager.syncWorkspace(session, files);
        await _sendJson(
          request.response,
          HttpStatus.ok,
          {'session': session.toJson()},
        );
        return;
      }

      if (segments.length == 3 && request.method == 'POST') {
        final session = manager.requireSession(sessionId);
        switch (segments[2]) {
          case 'run':
            await manager.run(session);
            await _sendAccepted(request.response, session);
            return;
          case 'hot-reload':
            await manager.hotReload(session);
            await _sendAccepted(request.response, session);
            return;
          case 'hot-restart':
            await manager.hotRestart(session);
            await _sendAccepted(request.response, session);
            return;
          case 'stop':
            await manager.stop(session);
            await _sendAccepted(request.response, session);
            return;
        }
      }

      await _sendError(
        request.response,
        HttpStatus.notFound,
        'Route not found.',
      );
    } on RunnerSessionNotFound catch (error) {
      await _sendError(
        request.response,
        HttpStatus.notFound,
        error.toString(),
      );
    } on FormatException catch (error) {
      await _sendError(
        request.response,
        HttpStatus.badRequest,
        error.toString(),
      );
    } on StateError catch (error) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        error.toString(),
      );
    } catch (error, stackTrace) {
      stderr.writeln('Runner request failed: $error');
      stderr.writeln(stackTrace);
      await _sendError(
        request.response,
        HttpStatus.internalServerError,
        error.toString(),
      );
    }
  }

  Future<void> _sendAccepted(
    HttpResponse response,
    RunnerSession session,
  ) {
    return _sendJson(
      response,
      HttpStatus.accepted,
      {'session': session.toJson()},
    );
  }

  Future<Map<String, dynamic>> _readJsonObject(HttpRequest request) async {
    final source = await utf8.decoder.bind(request).join();
    if (source.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Request body must be a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, String> _readFiles(Object? value) {
    if (value is! Map) {
      throw const FormatException('files must be a JSON object.');
    }

    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'Workspace files must map string paths to string contents.',
        );
      }
      result[entry.key as String] = entry.value as String;
    }
    return result;
  }

  Future<void> _sendError(
    HttpResponse response,
    int statusCode,
    String message,
  ) {
    return _sendJson(
      response,
      statusCode,
      {'error': message},
    );
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    _setCors(response);
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _sendEmpty(HttpResponse response, int statusCode) async {
    _setCors(response);
    response.statusCode = statusCode;
    await response.close();
  }

  void _setCors(HttpResponse response) {
    response.headers.set('access-control-allow-origin', allowedOrigin);
    response.headers.set(
      'access-control-allow-methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    response.headers.set(
      'access-control-allow-headers',
      'content-type, accept',
    );
    response.headers.set('cache-control', 'no-store');
  }
}
