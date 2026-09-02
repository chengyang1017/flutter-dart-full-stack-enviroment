import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../runner_session.dart';
import 'execution_backend.dart';

class LocalExecutionBackend implements RunnerExecutionBackend {
  LocalExecutionBackend({
    required this.flutterExecutable,
    this.dartExecutable = 'dart',
    this.dartFrogExecutable = 'dart_frog',
  });

  final String flutterExecutable;
  final String dartExecutable;
  final String dartFrogExecutable;

  @override
  String get name => 'local';

  @override
  Future<void> prepareSession(RunnerSession session) async {}

  @override
  Future<int> runFlutterCommand(
    RunnerSession session,
    List<String> arguments,
  ) {
    return _runLoggedProcess(
      session,
      flutterExecutable,
      arguments,
      workingDirectory: session.directory.path,
    );
  }

  @override
  Future<int> runDartCommand(
    RunnerSession session,
    List<String> arguments, {
    String workingDirectory = 'backend',
  }) {
    return _runLoggedProcess(
      session,
      dartExecutable,
      arguments,
      workingDirectory: _workingDirectory(session, workingDirectory),
      logPrefix: '[backend] ',
      stderrPrefix: '[backend stderr] ',
    );
  }

  @override
  Future<void> syncWorkspace(
    RunnerSession session, {
    required Set<String> removedPaths,
  }) async {}

  @override
  Future<RunnerProcessLaunch> startFlutterWeb(
    RunnerSession session, {
    Map<String, String> dartDefines = const <String, String>{},
  }) async {
    final port = await _reservePort();
    final arguments = <String>[
      'run',
      '-d',
      'web-server',
      '--web-hostname=0.0.0.0',
      '--web-port=$port',
      for (final entry in dartDefines.entries)
        '--dart-define=${entry.key}=${entry.value}',
    ];

    final process = await Process.start(
      flutterExecutable,
      arguments,
      workingDirectory: session.directory.path,
      runInShell: true,
    );

    return RunnerProcessLaunch(
      process: process,
      previewPort: port,
      description: 'flutter ${arguments.join(' ')}',
    );
  }

  @override
  Future<RunnerProcessLaunch> startDartFrog(
    RunnerSession session,
  ) async {
    final port = await _reservePort();
    final vmServicePort = await _reservePort();
    final arguments = <String>[
      'dev',
      '--host',
      '0.0.0.0',
      '--port',
      '$port',
      '--dart-vm-service-port',
      '$vmServicePort',
    ];

    final process = await Process.start(
      dartFrogExecutable,
      arguments,
      workingDirectory: _workingDirectory(session, 'backend'),
      runInShell: true,
    );

    return RunnerProcessLaunch(
      process: process,
      previewPort: port,
      description: 'dart_frog ${arguments.join(' ')}',
    );
  }

  @override
  Future<void> forceStop(
    RunnerSession session,
    Process process,
  ) async {
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  @override
  Future<void> disposeSession(RunnerSession session) async {}

  Future<int> _runLoggedProcess(
    RunnerSession session,
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    String logPrefix = '',
    String stderrPrefix = '[stderr] ',
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => session.addLog('$logPrefix$line'));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => session.addLog('$stderrPrefix$line'));
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    return exitCode;
  }

  String _workingDirectory(
    RunnerSession session,
    String relativePath,
  ) {
    if (relativePath.isEmpty || relativePath == '.') {
      return session.directory.path;
    }
    return [
      session.directory.path,
      ...relativePath.split('/'),
    ].join(Platform.pathSeparator);
  }

  Future<int> _reservePort() async {
    final socket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = socket.port;
    await socket.close();
    return port;
  }
}
