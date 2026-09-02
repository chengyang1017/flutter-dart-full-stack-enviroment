import 'dart:io';

import '../runner_session.dart';

class RunnerProcessLaunch {
  const RunnerProcessLaunch({
    required this.process,
    required this.previewPort,
    required this.description,
  });

  final Process process;
  final int previewPort;
  final String description;
}

abstract interface class RunnerExecutionBackend {
  String get name;

  Future<void> prepareSession(RunnerSession session);

  Future<int> runFlutterCommand(
    RunnerSession session,
    List<String> arguments,
  );

  Future<void> syncWorkspace(
    RunnerSession session, {
    required Set<String> removedPaths,
  });

  Future<RunnerProcessLaunch> startFlutterWeb(
    RunnerSession session,
  );

  Future<void> forceStop(
    RunnerSession session,
    Process process,
  );

  Future<void> disposeSession(RunnerSession session);
}
