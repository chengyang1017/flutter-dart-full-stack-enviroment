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
    required this.backendUrlTemplate,
  });

  static const flutterProjectType = 'flutter';
  static const flutterDartFrogProjectType = 'flutter-dart-frog';
  static const flutterServerpodMiniProjectType = 'flutter-serverpod-mini';
  static const serverpodServerDirectory = 'serverpod/practice_server';

  final Directory rootDirectory;
  final RunnerExecutionBackend executionBackend;
  final String previewUrlTemplate;
  final String backendUrlTemplate;

  final Map<String, RunnerSession> _sessions = <String, RunnerSession>{};
  int _nextSession = 1;

  Iterable<RunnerSession> get sessions => _sessions.values;
  String get executionBackendName => executionBackend.name;

  RunnerSession requireSession(String id) {
    final session = _sessions[id];
    if (session == null) throw RunnerSessionNotFound(id);
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
    )..projectType = _detectProjectType(files);
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
      session.addLog('[runner] ${_projectLabel(session)} session is ready.');
      return session;
    } catch (error) {
      session.setStatus('error');
      session.addLog('[runner] Session creation failed: $error');
      await _cleanupFailedSession(session);
      rethrow;
    }
  }

  Future<void> syncWorkspace(
    RunnerSession session,
    Map<String, String> files,
  ) async {
    final previousStatus = session.status;
    session.setStatus('syncing');

    for (final path in files.keys) {
      _validateRelativePath(path);
    }

    final incoming = files.keys.toSet();
    final removed = session.managedFiles.difference(incoming);

    try {
      for (final path in removed) {
        final file = File(_absolutePath(session, path));
        if (await file.exists()) await file.delete();
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
      session.projectType = _detectProjectType(files);

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
        '[runner] Synced ${files.length} workspace files '
        '(${session.projectType}).',
      );
    } catch (_) {
      session.setStatus('error');
      rethrow;
    }
  }

  Future<void> run(RunnerSession session) async {
    if (session.process != null || session.backendProcess != null) {
      throw StateError('Runner processes are already active.');
    }

    session.previewUrl = null;
    session.backendUrl = null;
    session.setStatus('starting');
    session.addLog('[runner] flutter pub get');

    final flutterPubExit = await executionBackend.runFlutterCommand(
      session,
      const ['pub', 'get'],
    );
    if (flutterPubExit != 0) {
      session.setStatus('error');
      throw StateError('flutter pub get exited with code $flutterPubExit');
    }

    final dartDefines = <String, String>{};

    try {
      if (_isDartFrog(session)) {
        await _startDartFrogBackend(session, dartDefines);
      } else if (_isServerpod(session)) {
        await _startServerpodBackend(session, dartDefines);
      }

      final launch = await executionBackend.startFlutterWeb(
        session,
        dartDefines: dartDefines,
      );
      session.previewUrl = previewUrlTemplate.replaceAll(
        '{port}',
        '${launch.previewPort}',
      );
      session.addLog('[runner] ${launch.description}');
      for (final entry in dartDefines.entries) {
        session.addLog('[runner] Injected ${entry.key}=${entry.value}');
      }
      session.process = launch.process;

      _listenToFlutterOutput(session, launch.process);
      unawaited(_watchFlutterExit(session, launch.process));
    } catch (error) {
      final backendProcess = session.backendProcess;
      if (backendProcess != null) {
        try {
          await _stopBackendProcess(session, backendProcess);
        } catch (_) {
          // Preserve the original run error.
        }
      }
      session.backendProcess = null;
      session.backendUrl = null;
      session.setStatus('error');
      rethrow;
    }
  }

  Future<void> hotReload(RunnerSession session) async {
    if (_isServerpod(session)) {
      await _restartServerpodStack(session, 'Hot reload');
      return;
    }

    final process = session.process;
    if (process == null || session.status != 'running') {
      throw StateError('Flutter process is not running.');
    }

    session.setStatus('reloading');
    final backendProcess = session.backendProcess;
    if (_isDartFrog(session) && backendProcess != null) {
      session.addLog('[backend] Hot reload requested.');
      backendProcess.stdin.writeln('r');
      await backendProcess.stdin.flush();
    }

    session.addLog('[runner] Flutter hot reload requested.');
    process.stdin.writeln('r');
    await process.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (session.process == process) session.setStatus('running');
  }

  Future<void> hotRestart(RunnerSession session) async {
    if (_isServerpod(session)) {
      await _restartServerpodStack(session, 'Hot restart');
      return;
    }

    final process = session.process;
    if (process == null || session.status != 'running') {
      throw StateError('Flutter process is not running.');
    }

    session.setStatus('restarting');
    final backendProcess = session.backendProcess;
    if (_isDartFrog(session) && backendProcess != null) {
      session.addLog('[backend] Hot restart requested.');
      backendProcess.stdin.writeln('R');
      await backendProcess.stdin.flush();
    }

    session.addLog('[runner] Flutter hot restart requested.');
    process.stdin.writeln('R');
    await process.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (session.process == process) session.setStatus('running');
  }

  Future<void> stop(RunnerSession session) async {
    final flutterProcess = session.process;
    final backendProcess = session.backendProcess;

    if (flutterProcess == null && backendProcess == null) {
      session.previewUrl = null;
      session.backendUrl = null;
      session.setStatus('stopped');
      return;
    }

    session.setStatus('stopping');

    if (flutterProcess != null) {
      await _stopFlutterProcess(session, flutterProcess);
    }
    if (backendProcess != null) {
      await _stopBackendProcess(session, backendProcess);
    }

    session.process = null;
    session.backendProcess = null;
    session.previewUrl = null;
    session.backendUrl = null;
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
      session.backendProcess?.kill();
      session.process = null;
      session.backendProcess = null;
    }

    try {
      await executionBackend.disposeSession(session);
    } catch (error) {
      session.addLog('[runner] Runtime cleanup failed: $error');
    }

    await _deleteSessionDirectory(session);
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

  Future<void> _startDartFrogBackend(
    RunnerSession session,
    Map<String, String> dartDefines,
  ) async {
    session.addLog('[backend] dart pub get');
    final backendPubExit = await executionBackend.runDartCommand(
      session,
      const ['pub', 'get'],
    );
    if (backendPubExit != 0) {
      throw StateError('backend dart pub get exited with code $backendPubExit');
    }

    final backendLaunch = await executionBackend.startDartFrog(session);
    _attachBackend(session, backendLaunch, framework: 'Dart Frog');
    dartDefines['API_URL'] = session.backendUrl!;
  }

  Future<void> _startServerpodBackend(
    RunnerSession session,
    Map<String, String> dartDefines,
  ) async {
    session.addLog('[serverpod] dart pub get');
    final pubExit = await executionBackend.runDartCommand(
      session,
      const ['pub', 'get'],
      workingDirectory: serverpodServerDirectory,
    );
    if (pubExit != 0) {
      throw StateError('Serverpod dart pub get exited with code $pubExit');
    }

    session.addLog('[serverpod] serverpod generate');
    final generateExit = await executionBackend.runServerpodCommand(
      session,
      const ['generate'],
      workingDirectory: serverpodServerDirectory,
    );
    if (generateExit != 0) {
      throw StateError('serverpod generate exited with code $generateExit');
    }

    final backendLaunch = await executionBackend.startServerpod(
      session,
      workingDirectory: serverpodServerDirectory,
    );
    _attachBackend(session, backendLaunch, framework: 'Serverpod');
    dartDefines['SERVERPOD_URL'] = session.backendUrl!;
  }

  void _attachBackend(
    RunnerSession session,
    RunnerProcessLaunch launch, {
    required String framework,
  }) {
    session.backendProcess = launch.process;
    session.backendUrl = backendUrlTemplate.replaceAll(
      '{port}',
      '${launch.previewPort}',
    );
    session.addLog('[backend] $framework: ${launch.description}');
    _listenToBackendOutput(session, launch.process, framework);
    unawaited(_watchBackendExit(session, launch.process, framework));
  }

  Future<void> _restartServerpodStack(
    RunnerSession session,
    String action,
  ) async {
    if (session.status != 'running') {
      throw StateError('Serverpod stack is not running.');
    }
    session.addLog(
      '[serverpod] $action regenerates the client and restarts the full stack.',
    );
    await stop(session);
    await run(session);
  }

  Future<void> _stopFlutterProcess(
    RunnerSession session,
    Process process,
  ) async {
    session.addLog('[runner] Stopping Flutter process...');
    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      session.addLog(
        '[runner] Graceful Flutter stop timed out; forcing runtime stop.',
      );
      await executionBackend.forceStop(session, process);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill();
      }
    }
    if (session.process == process) session.process = null;
  }

  Future<void> _stopBackendProcess(
    RunnerSession session,
    Process process,
  ) async {
    session.addLog('[backend] Stopping ${_backendLabel(session)} process...');
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 100));
    } on TimeoutException {
      await executionBackend.forceStop(session, process);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill();
      }
    }
    if (session.backendProcess == process) session.backendProcess = null;
  }

  void _listenToFlutterOutput(RunnerSession session, Process process) {
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

  void _listenToBackendOutput(
    RunnerSession session,
    Process process,
    String framework,
  ) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => session.addLog('[$framework] $line'));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => session.addLog('[$framework stderr] $line'));
  }

  Future<void> _watchFlutterExit(
    RunnerSession session,
    Process process,
  ) async {
    final exitCode = await process.exitCode;
    if (session.process != process) return;

    session.process = null;
    session.previewUrl = null;
    session.addLog('[runner] Flutter process exited with code $exitCode.');

    final stopping = session.status == 'stopping' || session.status == 'stopped';
    if (!stopping) {
      final backendProcess = session.backendProcess;
      if (backendProcess != null) {
        try {
          await _stopBackendProcess(session, backendProcess);
        } catch (error) {
          session.addLog('[backend] Cleanup after Flutter exit failed: $error');
        }
        session.backendProcess = null;
        session.backendUrl = null;
      }
    }

    if (stopping || exitCode == 0) {
      session.setStatus('stopped');
    } else {
      session.setStatus('error');
    }
  }

  Future<void> _watchBackendExit(
    RunnerSession session,
    Process process,
    String framework,
  ) async {
    final exitCode = await process.exitCode;
    if (session.backendProcess != process) return;

    session.backendProcess = null;
    session.backendUrl = null;
    session.addLog('[backend] $framework process exited with code $exitCode.');

    final stopping = session.status == 'stopping' || session.status == 'stopped';
    if (stopping) return;

    final flutterProcess = session.process;
    if (flutterProcess != null) {
      try {
        await _stopFlutterProcess(session, flutterProcess);
      } catch (error) {
        session.addLog('[runner] Cleanup after backend exit failed: $error');
      }
      session.process = null;
      session.previewUrl = null;
    }
    session.setStatus('error');
  }

  Future<void> _cleanupFailedSession(RunnerSession session) async {
    _sessions.remove(session.id);
    try {
      await executionBackend.disposeSession(session);
    } catch (cleanupError) {
      session.addLog('[runner] Runtime rollback failed: $cleanupError');
    }
    await _deleteSessionDirectory(session);
  }

  Future<void> _deleteSessionDirectory(RunnerSession session) async {
    if (await session.directory.exists()) {
      await session.directory.delete(recursive: true);
    }
  }

  bool _isDartFrog(RunnerSession session) {
    return session.projectType == flutterDartFrogProjectType;
  }

  bool _isServerpod(RunnerSession session) {
    return session.projectType == flutterServerpodMiniProjectType;
  }

  String _backendLabel(RunnerSession session) {
    return _isServerpod(session) ? 'Serverpod' : 'Dart Frog';
  }

  String _projectLabel(RunnerSession session) {
    return switch (session.projectType) {
      flutterDartFrogProjectType => 'Flutter + Dart Frog',
      flutterServerpodMiniProjectType => 'Flutter + Serverpod Mini',
      _ => 'Flutter',
    };
  }

  String _detectProjectType(Map<String, String> files) {
    final hasDartFrog = files.containsKey('backend/pubspec.yaml') &&
        files.keys.any(
          (path) => path.startsWith('backend/routes/') && path.endsWith('.dart'),
        );
    final hasServerpod = files.containsKey(
          'serverpod/practice_server/config/generator.yaml',
        ) &&
        files.containsKey('serverpod/practice_client/pubspec.yaml');

    if (hasDartFrog && hasServerpod) {
      throw const FormatException(
        'A practice workspace cannot enable Dart Frog and Serverpod together.',
      );
    }
    if (hasServerpod) return flutterServerpodMiniProjectType;
    if (hasDartFrog) return flutterDartFrogProjectType;
    return flutterProjectType;
  }

  String _absolutePath(RunnerSession session, String relativePath) {
    _validateRelativePath(relativePath);
    return [
      session.directory.path,
      ...relativePath.split('/'),
    ].join(Platform.pathSeparator);
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
