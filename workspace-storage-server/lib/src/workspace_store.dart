import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WorkspaceRevisionMismatch implements Exception {
  const WorkspaceRevisionMismatch({
    required this.workspaceId,
    required this.expectedRevision,
    required this.actualRevision,
  });

  final String workspaceId;
  final String expectedRevision;
  final String actualRevision;

  @override
  String toString() =>
      'WorkspaceRevisionMismatch(workspaceId: $workspaceId, '
      'expected: $expectedRevision, actual: $actualRevision)';
}

class WorkspaceDocumentNotFound implements Exception {
  const WorkspaceDocumentNotFound(this.workspaceId);

  final String workspaceId;

  @override
  String toString() => 'WorkspaceDocumentNotFound($workspaceId)';
}

class FileWorkspaceStore {
  FileWorkspaceStore(this.root);

  final Directory root;
  final Map<String, Future<void>> _userLocks = <String, Future<void>>{};

  Future<Map<String, dynamic>> loadCatalog(String userId) {
    return _serialized(userId, () => _readCatalog(userId));
  }

  Future<Map<String, dynamic>?> loadWorkspace(
    String userId,
    String workspaceId,
  ) {
    return _serialized(userId, () => _readDocument(userId, workspaceId));
  }

  Future<Map<String, dynamic>> createWorkspace({
    required String userId,
    required Map<String, dynamic> project,
    required Map<String, dynamic> snapshot,
  }) {
    return _serialized(userId, () async {
      final workspaceId = _readWorkspaceId(project);
      final existing = await _readDocument(userId, workspaceId);
      if (existing != null) {
        throw StateError('Workspace already exists: $workspaceId');
      }

      final document = <String, dynamic>{
        'project': project,
        'snapshot': snapshot,
        'revision': 'r1',
      };
      await _writeDocument(userId, workspaceId, document);

      final catalog = await _readCatalog(userId);
      final projects = _readProjects(catalog)
        ..removeWhere((item) => item['id'] == workspaceId)
        ..add(project);
      await _writeCatalog(
        userId,
        <String, dynamic>{
          'projects': projects,
          'revision': _nextRevision(catalog['revision'], 'c'),
        },
      );

      return document;
    });
  }

  Future<Map<String, dynamic>> saveWorkspace({
    required String userId,
    required String workspaceId,
    required Map<String, dynamic> project,
    required Map<String, dynamic> snapshot,
    required String expectedRevision,
  }) {
    return _serialized(userId, () async {
      if (_readWorkspaceId(project) != workspaceId) {
        throw const FormatException(
          'Workspace project id does not match the requested Workspace.',
        );
      }

      final current = await _readDocument(userId, workspaceId);
      if (current == null) {
        throw WorkspaceDocumentNotFound(workspaceId);
      }
      final actualRevision = current['revision'];
      if (actualRevision is! String || actualRevision.isEmpty) {
        throw StateError('Stored Workspace revision is invalid: $workspaceId');
      }
      if (actualRevision != expectedRevision) {
        throw WorkspaceRevisionMismatch(
          workspaceId: workspaceId,
          expectedRevision: expectedRevision,
          actualRevision: actualRevision,
        );
      }

      final document = <String, dynamic>{
        'project': project,
        'snapshot': snapshot,
        'revision': _nextRevision(actualRevision, 'r'),
      };
      await _writeDocument(userId, workspaceId, document);

      final catalog = await _readCatalog(userId);
      final projects = _readProjects(catalog);
      final index = projects.indexWhere((item) => item['id'] == workspaceId);
      if (index == -1) {
        projects.add(project);
      } else {
        projects[index] = project;
      }
      await _writeCatalog(
        userId,
        <String, dynamic>{
          'projects': projects,
          'revision': _nextRevision(catalog['revision'], 'c'),
        },
      );

      return document;
    });
  }

  Future<Map<String, dynamic>> deleteWorkspace({
    required String userId,
    required String workspaceId,
    required String expectedRevision,
  }) {
    return _serialized(userId, () async {
      final current = await _readDocument(userId, workspaceId);
      if (current == null) {
        throw WorkspaceDocumentNotFound(workspaceId);
      }
      final actualRevision = current['revision'];
      if (actualRevision is! String || actualRevision.isEmpty) {
        throw StateError('Stored Workspace revision is invalid: $workspaceId');
      }
      if (actualRevision != expectedRevision) {
        throw WorkspaceRevisionMismatch(
          workspaceId: workspaceId,
          expectedRevision: expectedRevision,
          actualRevision: actualRevision,
        );
      }

      final file = _documentFile(userId, workspaceId);
      if (await file.exists()) {
        await file.delete();
      }

      final catalog = await _readCatalog(userId);
      final projects = _readProjects(catalog)
        ..removeWhere((item) => item['id'] == workspaceId);
      final next = <String, dynamic>{
        'projects': projects,
        'revision': _nextRevision(catalog['revision'], 'c'),
      };
      await _writeCatalog(userId, next);
      return next;
    });
  }

  Future<T> _serialized<T>(
    String userId,
    Future<T> Function() action,
  ) async {
    final previous = _userLocks[userId] ?? Future<void>.value();
    final completer = Completer<void>();
    final current = completer.future;
    _userLocks[userId] = current;

    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_userLocks[userId], current)) {
        _userLocks.remove(userId);
      }
    }
  }

  Future<Map<String, dynamic>> _readCatalog(String userId) async {
    final file = _catalogFile(userId);
    if (!await file.exists()) {
      return <String, dynamic>{
        'projects': <Map<String, dynamic>>[],
        'revision': 'c0',
      };
    }
    return _readJsonObject(file, 'Workspace catalog');
  }

  Future<Map<String, dynamic>?> _readDocument(
    String userId,
    String workspaceId,
  ) async {
    final file = _documentFile(userId, workspaceId);
    if (!await file.exists()) return null;
    return _readJsonObject(file, 'Workspace document');
  }

  Future<Map<String, dynamic>> _readJsonObject(
    File file,
    String label,
  ) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw FormatException('$label must be a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  List<Map<String, dynamic>> _readProjects(Map<String, dynamic> catalog) {
    final raw = catalog['projects'];
    if (raw is! Iterable) {
      throw const FormatException('Workspace catalog projects are invalid.');
    }
    return raw.map((item) {
      if (item is! Map) {
        throw const FormatException('Workspace catalog project is invalid.');
      }
      return Map<String, dynamic>.from(item);
    }).toList(growable: true);
  }

  String _readWorkspaceId(Map<String, dynamic> project) {
    final id = project['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Workspace project id is required.');
    }
    return id;
  }

  String _nextRevision(Object? current, String prefix) {
    if (current is! String || !current.startsWith(prefix)) {
      throw FormatException('Invalid $prefix revision: $current');
    }
    final number = int.tryParse(current.substring(prefix.length));
    if (number == null || number < 0) {
      throw FormatException('Invalid $prefix revision: $current');
    }
    return '$prefix${number + 1}';
  }

  Future<void> _writeCatalog(
    String userId,
    Map<String, dynamic> catalog,
  ) {
    return _writeJson(_catalogFile(userId), catalog);
  }

  Future<void> _writeDocument(
    String userId,
    String workspaceId,
    Map<String, dynamic> document,
  ) {
    return _writeJson(_documentFile(userId, workspaceId), document);
  }

  Future<void> _writeJson(File file, Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  File _catalogFile(String userId) =>
      File('${_userDirectory(userId).path}/catalog.json');

  File _documentFile(String userId, String workspaceId) => File(
        '${_userDirectory(userId).path}/documents/${_key(workspaceId)}.json',
      );

  Directory _userDirectory(String userId) =>
      Directory('${root.path}/users/${_key(userId)}');

  String _key(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}
