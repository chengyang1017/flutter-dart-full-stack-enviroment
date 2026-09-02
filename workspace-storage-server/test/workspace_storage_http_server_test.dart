import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:workspace_storage_server/workspace_storage_server.dart';

void main() {
  late Directory temp;
  late HttpServer rawServer;
  late HttpClient client;
  late Uri baseUri;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('workspace-http-test-');
    final handler = WorkspaceStorageHttpServer(
      store: FileWorkspaceStore(temp),
      authenticator: const StaticBearerWorkspaceAuthenticator(
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
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('requires auth and keeps Workspace catalogs user-scoped', () async {
    final unauthorized = await _request(client, baseUri, 'GET', 'workspaces');
    expect(unauthorized.statusCode, HttpStatus.unauthorized);

    final created = await _request(
      client,
      baseUri,
      'POST',
      'workspaces',
      token: 'alice-token',
      body: <String, dynamic>{
        'project': _project('workspace-a'),
        'snapshot': _snapshot(),
      },
    );
    expect(created.statusCode, HttpStatus.created);
    expect(created.json['revision'], 'r1');

    final bobCatalog = await _request(
      client,
      baseUri,
      'GET',
      'workspaces',
      token: 'bob-token',
    );
    expect(bobCatalog.statusCode, HttpStatus.ok);
    expect(bobCatalog.json['projects'], isEmpty);

    final bobRead = await _request(
      client,
      baseUri,
      'GET',
      'workspaces/workspace-a',
      token: 'bob-token',
    );
    expect(bobRead.statusCode, HttpStatus.notFound);

    final aliceRead = await _request(
      client,
      baseUri,
      'GET',
      'workspaces/workspace-a',
      token: 'alice-token',
    );
    expect(aliceRead.statusCode, HttpStatus.ok);
    expect((aliceRead.json['project'] as Map)['id'], 'workspace-a');
  });

  test('returns structured revision conflicts', () async {
    await _request(
      client,
      baseUri,
      'POST',
      'workspaces',
      token: 'alice-token',
      body: <String, dynamic>{
        'project': _project('workspace-a'),
        'snapshot': _snapshot(),
      },
    );

    final conflict = await _request(
      client,
      baseUri,
      'PUT',
      'workspaces/workspace-a',
      token: 'alice-token',
      body: <String, dynamic>{
        'project': _project('workspace-a'),
        'snapshot': _snapshot(),
        'expectedRevision': 'r0',
      },
    );

    expect(conflict.statusCode, HttpStatus.conflict);
    expect(conflict.json['code'], 'revision_conflict');
    expect(conflict.json['expectedRevision'], 'r0');
    expect(conflict.json['actualRevision'], 'r1');
  });
}

Future<_TestResponse> _request(
  HttpClient client,
  Uri baseUri,
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  final request = await client.openUrl(method, baseUri.resolve(path));
  request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final text = await utf8.decoder.bind(response).join();
  final decoded = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text);
  return _TestResponse(
    response.statusCode,
    decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{},
  );
}

class _TestResponse {
  const _TestResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, dynamic> json;
}

Map<String, dynamic> _project(String id) => <String, dynamic>{
      'id': id,
      'name': id,
      'storageKey': 'workspace:$id',
      'kind': 'practice',
      'lifecycle': 'saved',
      'createdAt': '2026-09-03T00:00:00.000Z',
      'updatedAt': '2026-09-03T00:00:00.000Z',
    };

Map<String, dynamic> _snapshot() => <String, dynamic>{
      'formatVersion': 2,
      'entries': <Object>[],
      'baseEntries': <Object>[],
      'openFiles': <Object>[],
      'activePath': '',
      'nextId': 1,
      'savedAt': '2026-09-03T00:00:00.000Z',
      'expandedDirectoryIds': <Object>[],
      'editorStates': <String, Object?>{},
    };
