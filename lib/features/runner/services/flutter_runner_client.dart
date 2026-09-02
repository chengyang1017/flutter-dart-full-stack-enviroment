import '../../workspace/models/workspace_change.dart';
import '../models/run_session.dart';
import '../models/runner_event.dart';

abstract interface class FlutterRunnerClient {
  String get displayName;
  bool get isMock;

  Future<RunSession> createSession({
    required Map<String, String> files,
  });

  Stream<RunnerEvent> watchSession(String sessionId);

  Future<void> syncWorkspace({
    required String sessionId,
    required Map<String, String> files,
    required List<WorkspaceChange> changes,
  });

  Future<void> run(String sessionId);

  Future<void> hotReload(String sessionId);

  Future<void> hotRestart(String sessionId);

  Future<void> stop(String sessionId);

  Future<void> disposeSession(String sessionId);
}
