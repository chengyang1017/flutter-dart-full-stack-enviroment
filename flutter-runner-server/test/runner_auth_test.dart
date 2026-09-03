import 'dart:convert';
import 'dart:io';

import 'package:flutter_practice_runner_server/src/execution/execution_backend.dart';
import 'package:flutter_practice_runner_server/src/runner_authenticator.dart';
import 'package:flutter_practice_runner_server/src/runner_server.dart';
import 'package:flutter_practice_runner_server/src/runner_session.dart';
import 'package:flutter_practice_runner_server/src/session_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late HttpServer rawServer;
  late HttpClient client;
  late Uri baseUri;
  late SessionManager manager;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('runner-auth-test-');
    manager = SessionManager(
      rootDirectory: temp,
      executionBackend: _FakeExecutionBackend(),
      previewUrlTemplate: 'http://localhost:{port}',
      backendUrlTemplate: 'http://localhost:{port}',
    );
    final handler = RunnerServer(
      manager: manager,
      authenticator: const StaticBearerRunnerAuthenticator(
        <String, String>{
          'alice-token': 'alice',
          'bob-token': 'bob',
        },
      ),
    );
    rawServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    rawServer.listen(handler.handle);
    client = HttpClient();
    baseUri = Uri.parse('http://127.0.0.1:${rawServer.port}/');
  });

  tearDown(() async {
    client.close(force: true);
    await rawServer.close(force: true);
    await manager.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('sessions require authentication and are scoped to their owner', () async {
    final unauthenticated = await _request(client, baseUri, 'POST', 'sessions');
    expect(unauthenticated.statusCode, HttpStatus.unauthorized);

    final created = await _request(
      client,
      baseUri,
      'POST',
      'sessions',
      token: 'alice-token',
      body: '{"files":{"lib/main.dart":"void main() {}"}}',
    );
    expect(created.statusCode, HttpStatus.created);
    final sessionId = RegExp(r'"id":"([^"]+)"')
        .firstMatch(created.body)!
        .group(1)!;

    final aliceRead = await _request(
      client,
      baseUri,
      'GET',
      'sessions/$sessionId',
      token: 'alice-token',
    );
    expect(aliceRead.statusCode, HttpStatus.ok);

    final bobRead = await _request(
      client,
      baseUri,
      'GET',
      'sessions/$sessionId',
      token: 'bob-token',
    );
    expect(bobRead.statusCode, HttpStatus.notFound);
  });

  test('auth token mapping validates configuration', () {
    final auth = StaticBearerRunnerAuthenticator.fromJson(
      '{"runner-token":"user-1"}',
    );
    expect(auth.tokenToUserId['runner-token'], 'user-1');
    expect(
      () => StaticBearerRunnerAuthenticator.fromJson('{}'),
      throwsFormatException,
    );
  });
}

Future<_Response> _request(
  HttpClient client,
  Uri baseUri,
  String method,
  String path, {
  String? token,
  String? body,
}) async {
  final request = await client.openUrl(method, baseUri.resolve(path));
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(body);
  }
  final response = await request.close();
  final text = await utf8.decoder.bind(response).join();
  return _Response(response.statusCode, text);
}

class _Response {
  const _Response(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

class _FakeExecutionBackend implements RunnerExecutionBackend {
  @override
  String get name => 'fake';

  @override
  Future<void> prepareSession(RunnerSession session) async {}

  @override
  Future<int> runFlutterCommand(
    RunnerSession session,
    List<String> arguments,
  ) async => 0;

  @override
  Future<void> syncWorkspace(
    RunnerSession session, {
    required Set<String> removedPaths,
  }) async {}

  @override
  Future<int> runDartCommand(
    RunnerSession session,
    List<String> arguments, {
    String workingDirectory = 'backend',
  }) async => 0;

  @override
  Future<int> runServerpodCommand(
    RunnerSession session,
    List<String> arguments, {
    String workingDirectory = 'serverpod/practice_server',
  }) async => 0;

  @override
  Future<RunnerProcessLaunch> startFlutterWeb(
    RunnerSession session, {
    Map<String, String> dartDefines = const <String, String>{},
  }) => throw UnimplementedError();

  @override
  Future<RunnerProcessLaunch> startDartFrog(RunnerSession session) =>
      throw UnimplementedError();

  @override
  Future<RunnerProcessLaunch> startServerpod(
    RunnerSession session, {
    String workingDirectory = 'serverpod/practice_server',
  }) => throw UnimplementedError();

  @override
  Future<void> forceStop(RunnerSession session, Process process) async {}

  @override
  Future<void> disposeSession(RunnerSession session) async {}
}
