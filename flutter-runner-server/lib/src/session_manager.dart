import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'execution/execution_backend.dart';
import 'runner_session.dart';

class SessionManager {
  SessionManager({
    required this.rootDirectory,
    required this.executionBackend,
    required this.previewUrlTemplate,
  });

  final Directory rootDirectory;
  final RunnerExecutionBackend executionBackend;
  final String previewUrlTemplate;

  final Map<String, RunnerSession> _sessions = <String, RunnerSession>{};
  int _nextSession = 1;

  Iterable<RunnerSession> get sessions => _sessions.values;
  String get executionBackendName => executionBackend.name;

  RunnerSession requireSession(String id) {
    final session = _sessions[id];
    if (session == null) {
      throw RunnerSessionNotFound(id);
    }
    return session;
  }

  Future<RunnerSession> createSession(Map<String, String> files) async {
    await rootDirectory.create(recursive: true);

    final now = DateTime.now().toUtc();
    final id = 'flutter-${now.microsecondsSinceEpoch}-${_nextSession++}';
    final directory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}$id',
    );
    await directory.create(recursive: true);

    final session = RunnerSession(
      id: id,
      directory: directory,
      createdAt: now,
    );
    _sessions[id] = session;

    try {
      session.addLog(
        '[runner] Preparing ${executionBackend.name} execution backend...',
      );
      await executionBackend.prepareSession(session);

      session.addLog('[runner] Creating web-capable Flutter project...');
      final createExit = await executionBackend.runFlutterCommand(
        session,
        const [
          'create',
          '--no-pub',
          '--platforms=web',
          '--project-name=flutter_practice',
          '.',
        ],
      );
      if (createExit != 0) {
        throw StateError('flutter create exited with code $createExit');
      }

      await syncWorkspace(session, files);
      session.setStatus('ready');
      session.addLog('[runner] Flutter session is ready.');
      return session;
    } catch (error) {
      session.setStatus('error');
      session.addLog('[runner] Session creation failed: $error');
      rethrow;
    }
  }

  Future<void> syncWorkspace(
    RunnerSession session,
    Map<String, String> files,
  ) async {
    final previousStatus = session.status;
    session.setStatus('syncing');

    // Validate the complete incoming set before mutating host/container state.
    for (final path in files.keys) {
      _validateRelativePath(path);
    }

    final incoming = files.keys.toSet();
    final removed = session.managedFiles.difference(incoming);

    try {
      for (final path in removed) {
        final file = File(_absolutePath(session, path));
        if (await file.exists()) {
          await file.delete();
        }
      }

      for (final entry in files.entries) {
        final file = File(_absolutePath(session, entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value, flush: true);
      }

      await executionBackend.syncWorkspace(
        session,
        removedPaths: removed,
      );

      session.managedFiles
        ..clear()
        ..addAll(incoming);

      if (previousStatus == 'running' ||
          previousStatus == 'reloading' ||
          previousStatus == 'restarting') {
        session.setStatus('running');
      } else if (previousStatus == 'stopped') {
        session.setStatus('stopped');
      } else {
        session.setStatus('ready');
      }

      session.addLog(
        '[runner] Synced ${files.length} workspace files.',
      );
    } catch (_) {
      session.setStatus('error');
      rethrow;
    }
  }

  Future<void> run(RunnerSession session) async {
    if (session.process != null) {
      throw StateError('Flutter process is already running.');
    }

    session.previewUrl = null;
    session.setStatus('starting');
    session.addLog('[runner] flutter pub get');

    final pubExit = await executionBackend.runFlutterCommand(
      session,
      const ['pub', 'get'],
    );
    if (pubExit != 0) {
      session.setStatus('error');
      throw StateError('flutter pub get exited with code $pubExit');
    }

    try {
      final launch = await executionBackend.startFlutterWeb(session);
      session.previewUrl = previewUrlTemplate.replaceAll(
        '{port}',
        '${launch.previewPort}',
      );
      session.addLog('[runner] ${launch.description}');
      session.process = launch.process;

      _listenToFlutterOutput(session, launch.process);
      unawaited(_watchProcessExit(session, launch.process));
    } catch (_) {
      session.setStatus('error');
      rethrow;
    }
  }

  Future<void> hotReload(RunnerSession session) async {
    final process = session.process;
    if (process == null || session.status != 'running') {
      throw StateError('Flutter process is not running.');
    }

    session.setStatus('reloading');
    session.addLog('[runner] Hot reload requested.');
    process.stdin.writeln('r');
    await process.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (session.process == process) {
      session.setStatus('running');
    }
  }

  Future<void> hotRestart(RunnerSession session) async {
    final process = session.process;
    if (process == null || session.status != 'running') {
      throw StateError('Flutter process is not running.');
    }

    session.setStatus('restarting');
    session.addLog('[runner] Hot restart requested.');
    process.stdin.writeln('R');
    await process.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (session.process == process) {
      session.setStatus('running');
    }
  }

  Future<void> stop(RunnerSession session) async {
    final process = session.process;
    if (process == null) {
      session.previewUrl = null;
      session.setStatus('stopped');
      return;
    }

    session.setStatus('stopping');
    session.addLog('[runner] Stopping Flutter process...');

    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      session.addLog(
        '[runner] Graceful stop timed out; forcing runtime stop.',
      );
      await executionBackend.forceStop(session, process);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill();
      }
    }

    if (session.process == process) {
      session.process = null;
    }
    session.previewUrl = null;
    session.setStatus('stopped');
  }

  Future<void> disposeSession(String id) async {
    final session = _sessions.remove(id);
    if (session == null) return;

    try {
      await stop(session);
    } catch (error) {
      session.addLog('[runner] Stop during cleanup failed: $error');
      session.process?.kill();
      session.process = null;
    }

    try {
      await executionBackend.disposeSession(session);
    } catch (error) {
      session.addLog('[runner] Runtime cleanup failed: $error');
    }

    if (await session.directory.exists()) {
      await session.directory.delete(recursive: true);
    }
  }

  Future<int> disposeIdleSessions(Duration maxIdle) async {
    final cutoff = DateTime.now().toUtc().subtract(maxIdle);
    final idleIds = _sessions.values
        .where((session) => session.lastActivityAt.isBefore(cutoff))
        .map((session) => session.id)
        .toList(growable: false);

    for (final id in idleIds) {
      await disposeSession(id);
    }
    return idleIds.length;
  }

  Future<void> dispose() async {
    for (final id in _sessions.keys.toList()) {
      await disposeSession(id);
    }
  }

  void _listenToFlutterOutput(
    RunnerSession session,
    Process process,
  ) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      session.addLog(line);
      if (session.process == process &&
          session.status == 'starting' &&
          (line.contains('is being served at') ||
              line.contains('Flutter run key commands') ||
              line.contains('A Dart VM Service'))) {
        session.setStatus('running');
      }
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => session.addLog('[stderr] $line'));
  }

  Future<void> _watchProcessExit(
    RunnerSession session,
    Process process,
  ) async {
    final exitCode = await process.exitCode;
    if (session.process != process) return;

    session.process = null;
    session.previewUrl = null;
    session.addLog('[runner] Flutter process exited with code $exitCode.');

    if (session.status == 'stopping' || session.status == 'stopped') {
      session.setStatus('stopped');
    } else if (exitCode == 0) {
      session.setStatus('stopped');
    } else {
      session.setStatus('error');
    }
  }

  String _absolutePath(RunnerSession session, String relativePath) {
    _validateRelativePath(relativePath);
    final segments = relativePath.split('/');
    return [session.directory.path, ...segments].join(Platform.pathSeparator);
  }

  void _validateRelativePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.contains('\\')) {
      throw FormatException('Invalid workspace path: $path');
    }
    final segments = path.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw FormatException('Invalid workspace path: $path');
    }
  }
}

class RunnerSessionNotFound implements Exception {
  const RunnerSessionNotFound(this.id);

  final String id;

  @override
  String toString() => 'Runner session not found: $id';
}
