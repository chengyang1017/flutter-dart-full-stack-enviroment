import '../controllers/workspace_controller.dart';

class DartFrogWorkspaceService {
  const DartFrogWorkspaceService();

  static const backendPubspecPath = 'backend/pubspec.yaml';
  static const backendRoutePath = 'backend/routes/index.dart';
  static const backendMiddlewarePath = 'backend/routes/_middleware.dart';
  static const backendStatusRoutePath = 'backend/routes/api/status.dart';
  static const backendEchoRoutePath = 'backend/routes/api/echo.dart';
  static const apiClientPath = 'lib/dart_frog_api.dart';

  bool isEnabled(WorkspaceController workspace) {
    return workspace.entryAt(backendPubspecPath)?.isFile == true &&
        workspace.entryAt(backendRoutePath)?.isFile == true;
  }

  void ensureEnabled(WorkspaceController workspace) {
    final mainSource = workspace.entryAt('lib/main.dart')?.content ?? '';
    final shouldInstallStarter = _looksLikeStarterMain(mainSource);

    _ensureDirectory(workspace, 'backend');
    _ensureDirectory(workspace, 'backend/routes');
    _ensureDirectory(workspace, 'backend/routes/api');
    _ensureDirectory(workspace, 'backend/lib');
    _ensureDirectory(workspace, 'backend/test');

    _ensureFile(
      workspace,
      backendPubspecPath,
      _backendPubspec,
    );
    _ensureBackendDependencies(workspace);
    _ensureFile(
      workspace,
      backendRoutePath,
      _backendRoute,
    );
    _ensureFile(
      workspace,
      backendMiddlewarePath,
      _backendMiddleware,
    );
    _ensureFile(
      workspace,
      backendStatusRoutePath,
      _backendStatusRoute,
    );
    _ensureFile(
      workspace,
      backendEchoRoutePath,
      _backendEchoRoute,
    );
    _ensureFile(
      workspace,
      apiClientPath,
      _apiClient,
    );
    _ensureHttpDependency(workspace);

    if (shouldInstallStarter) {
      workspace.updateFileContent('lib/main.dart', _fullStackMain);
    }
  }

  void _ensureDirectory(
    WorkspaceController workspace,
    String path,
  ) {
    final existing = workspace.entryAt(path);
    if (existing != null) {
      if (!existing.isDirectory) {
        throw StateError('$path already exists and is not a directory.');
      }
      return;
    }

    final separator = path.lastIndexOf('/');
    final parent = separator == -1 ? '' : path.substring(0, separator);
    final name = separator == -1 ? path : path.substring(separator + 1);
    workspace.createDirectory(parent, name);
  }

  void _ensureFile(
    WorkspaceController workspace,
    String path,
    String content,
  ) {
    final existing = workspace.entryAt(path);
    if (existing != null) {
      if (!existing.isFile) {
        throw StateError('$path already exists and is not a file.');
      }
      return;
    }

    final separator = path.lastIndexOf('/');
    final parent = separator == -1 ? '' : path.substring(0, separator);
    final name = separator == -1 ? path : path.substring(separator + 1);
    workspace.createFile(parent, name, content: content);
  }

  void _ensureHttpDependency(WorkspaceController workspace) {
    _ensureDependency(
      workspace,
      path: 'pubspec.yaml',
      packageName: 'http',
      constraint: '^1.6.0',
    );
  }

  void _ensureBackendDependencies(WorkspaceController workspace) {
    _ensureDependency(
      workspace,
      path: backendPubspecPath,
      packageName: 'dart_frog',
      constraint: '^1.2.6',
    );
    _ensureDependency(
      workspace,
      path: backendPubspecPath,
      packageName: 'shelf_cors_headers',
      constraint: '^0.1.5',
    );
  }

  void _ensureDependency(
    WorkspaceController workspace, {
    required String path,
    required String packageName,
    required String constraint,
  }) {
    final entry = workspace.entryAt(path);
    if (entry == null || !entry.isFile) {
      throw StateError('$path is missing.');
    }

    final source = entry.content;
    if (RegExp(
      '^\\s{2}${RegExp.escape(packageName)}\\s*:',
      multiLine: true,
    ).hasMatch(source)) {
      return;
    }

    const dependencies = 'dependencies:\n';
    if (!source.contains(dependencies)) {
      throw StateError('$path has no dependencies section.');
    }

    workspace.updateFileContent(
      path,
      source.replaceFirst(
        dependencies,
        '$dependencies  $packageName: $constraint\n',
      ),
    );
  }

  bool _looksLikeStarterMain(String source) {
    return source.contains('class PracticeExample') &&
        source.contains("'万文社'") &&
        source.contains("'Glyphora'");
  }

  static const _backendPubspec = '''name: practice_backend
description: Dart Frog backend for the Flutter practice workspace.
publish_to: none

environment:
  sdk: ^3.4.0

dependencies:
  dart_frog: ^1.2.6
  shelf_cors_headers: ^0.1.5
''';

  static const _backendRoute = '''import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'message': 'Hello from Dart Frog!',
      'servedAt': DateTime.now().toUtc().toIso8601String(),
    },
  );
}
''';

  static const _backendMiddleware = '''import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf;

Handler middleware(Handler handler) {
  return handler.use(
    fromShelfMiddleware(
      shelf.corsHeaders(
        headers: const {
          shelf.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
          shelf.ACCESS_CONTROL_ALLOW_HEADERS: 'Origin, Content-Type, Accept',
          shelf.ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, OPTIONS',
        },
      ),
    ),
  );
}
''';

  static const _backendStatusRoute = '''import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(
        body: {
          'status': 'ok',
          'framework': 'dart_frog',
          'servedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}
''';

  static const _backendEchoRoute = '''import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.post:
      final body = await context.request.json();
      return Response.json(
        body: {
          'received': body,
          'servedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}
''';

  static const _apiClient = '''import 'dart:convert';

import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment('API_URL');

Future<String> loadDartFrogMessage() async {
  if (apiUrl.isEmpty) {
    return 'API_URL is injected by the real runner when you press Run.';
  }

  Object? lastError;
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is String) {
          return decoded['message'] as String;
        }
        return response.body;
      }
      lastError = 'HTTP \${response.statusCode}: \${response.body}';
    } catch (error) {
      lastError = error;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  throw StateError('Dart Frog request failed: \$lastError');
}
''';

  static const _fullStackMain = '''import 'package:flutter/material.dart';

import 'dart_frog_api.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FullStackPractice(),
    ),
  );
}

class FullStackPractice extends StatefulWidget {
  const FullStackPractice({super.key});

  @override
  State<FullStackPractice> createState() => _FullStackPracticeState();
}

class _FullStackPracticeState extends State<FullStackPractice> {
  late Future<String> message;

  @override
  void initState() {
    super.initState();
    message = loadDartFrogMessage();
  }

  void reload() {
    setState(() {
      message = loadDartFrogMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full Stack Practice')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
// QUICK_PREVIEW_START
Text(
  'Flutter + Dart Frog',
  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
)
// QUICK_PREVIEW_END
              ,
              const SizedBox(height: 20),
              FutureBuilder<String>(
                future: message,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Backend error: \${snapshot.error}');
                  }
                  return Text(
                    snapshot.data ?? 'No backend message',
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Call Dart Frog again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';
}
