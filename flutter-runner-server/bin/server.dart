import 'dart:async';
import 'dart:io';

import 'package:flutter_practice_runner_server/src/execution/docker_execution_backend.dart';
import 'package:flutter_practice_runner_server/src/execution/execution_backend.dart';
import 'package:flutter_practice_runner_server/src/execution/local_execution_backend.dart';
import 'package:flutter_practice_runner_server/src/runner_server.dart';
import 'package:flutter_practice_runner_server/src/session_manager.dart';

Future<void> main() async {
  final environment = Platform.environment;
  final host = environment['RUNNER_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(environment['RUNNER_PORT'] ?? '') ?? 8787;
  final allowedOrigin = environment['RUNNER_ALLOWED_ORIGIN'] ?? '*';
  final idleMinutes = int.tryParse(
        environment['RUNNER_IDLE_MINUTES'] ?? '',
      ) ??
      20;
  final previewUrlTemplate =
      environment['RUNNER_PREVIEW_URL_TEMPLATE'] ?? 'http://localhost:{port}';
  final workspaceRoot = Directory(
    environment['RUNNER_WORKSPACE_ROOT'] ??
        '${Directory.systemTemp.path}${Platform.pathSeparator}flutter-practice-runner',
  );
  final executionBackend = _createExecutionBackend(environment);

  final manager = SessionManager(
    rootDirectory: workspaceRoot,
    executionBackend: executionBackend,
    previewUrlTemplate: previewUrlTemplate,
  );
  final runnerServer = RunnerServer(
    manager: manager,
    allowedOrigin: allowedOrigin,
  );

  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    'Flutter Practice Runner listening on http://$host:${server.port}',
  );
  stdout.writeln('Workspace root: ${workspaceRoot.path}');
  stdout.writeln('Execution backend: ${executionBackend.name}');
  stdout.writeln('Idle session timeout: $idleMinutes minutes');

  final cleanupTimer = Timer.periodic(
    const Duration(minutes: 1),
    (_) {
      unawaited(() async {
        final removed = await manager.disposeIdleSessions(
          Duration(minutes: idleMinutes),
        );
        if (removed > 0) {
          stdout.writeln('Disposed $removed idle runner session(s).');
        }
      }());
    },
  );

  var shuttingDown = false;
  Future<void> shutdown() async {
    if (shuttingDown) return;
    shuttingDown = true;
    cleanupTimer.cancel();
    stdout.writeln('Stopping Flutter Practice Runner...');
    await server.close(force: true);
    await manager.dispose();
  }

  ProcessSignal.sigint.watch().listen((_) {
    unawaited(shutdown());
  });

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) {
      unawaited(shutdown());
    });
  }

  await for (final request in server) {
    unawaited(runnerServer.handle(request));
  }
}

RunnerExecutionBackend _createExecutionBackend(
  Map<String, String> environment,
) {
  final mode =
      (environment['RUNNER_EXECUTION_MODE'] ?? 'local').trim().toLowerCase();

  switch (mode) {
    case 'local':
      return LocalExecutionBackend(
        flutterExecutable: environment['FLUTTER_EXECUTABLE'] ?? 'flutter',
      );
    case 'docker':
      return DockerExecutionBackend(
        dockerExecutable: environment['DOCKER_EXECUTABLE'] ?? 'docker',
        image: environment['RUNNER_DOCKER_IMAGE'] ??
            'flutter-practice-runner:local',
        flutterExecutable:
            environment['RUNNER_CONTAINER_FLUTTER_EXECUTABLE'] ?? 'flutter',
        memoryLimit: environment['RUNNER_DOCKER_MEMORY'] ?? '1024m',
        cpuLimit: environment['RUNNER_DOCKER_CPUS'] ?? '1.0',
        pidsLimit: int.tryParse(
              environment['RUNNER_DOCKER_PIDS_LIMIT'] ?? '',
            ) ??
            256,
        network: environment['RUNNER_DOCKER_NETWORK'],
        runnerOwnership:
            environment['RUNNER_DOCKER_RUNNER_OWNERSHIP'] ?? '10001:10001',
      );
    default:
      throw ArgumentError.value(
        mode,
        'RUNNER_EXECUTION_MODE',
        'Expected local or docker.',
      );
  }
}
