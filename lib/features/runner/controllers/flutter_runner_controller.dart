import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../workspace/controllers/workspace_controller.dart';
import '../models/run_session.dart';
import '../models/runner_event.dart';
import '../services/flutter_runner_client.dart';

class FlutterRunnerController extends ChangeNotifier {
  FlutterRunnerController({
    required this.workspace,
    required this.client,
  });

  final WorkspaceController workspace;
  final FlutterRunnerClient client;

  RunSession? session;
  RunnerStatus status = RunnerStatus.idle;
  final List<String> logs = [];

  StreamSubscription<RunnerEvent>? _eventsSubscription;
  bool _disposed = false;

  bool get isMock => client.isMock;
  String get runnerName => client.displayName;
  String? get previewUrl => session?.previewUrl;

  bool get isBusy => const {
        RunnerStatus.creating,
        RunnerStatus.syncing,
        RunnerStatus.starting,
        RunnerStatus.reloading,
        RunnerStatus.restarting,
        RunnerStatus.stopping,
      }.contains(status);

  bool get canRun => !isBusy && status != RunnerStatus.running;
  bool get canHotReload => !isBusy && status == RunnerStatus.running;
  bool get canHotRestart => !isBusy && status == RunnerStatus.running;
  bool get canStop => !isBusy &&
      session != null &&
      status != RunnerStatus.idle &&
      status != RunnerStatus.stopped;

  Future<void> run() async {
    if (!canRun) return;

    try {
      final currentSession = await _ensureSession();
      await client.syncWorkspace(
        sessionId: currentSession.id,
        files: _workspaceFiles(),
        changes: workspace.changes,
      );
      await client.run(currentSession.id);
    } catch (error) {
      _fail('Run failed', error);
    }
  }

  Future<void> hotReload() async {
    if (!canHotReload || session == null) return;

    try {
      await client.syncWorkspace(
        sessionId: session!.id,
        files: _workspaceFiles(),
        changes: workspace.changes,
      );
      await client.hotReload(session!.id);
    } catch (error) {
      _fail('Hot reload failed', error);
    }
  }

  Future<void> hotRestart() async {
    if (!canHotRestart || session == null) return;

    try {
      await client.syncWorkspace(
        sessionId: session!.id,
        files: _workspaceFiles(),
        changes: workspace.changes,
      );
      await client.hotRestart(session!.id);
    } catch (error) {
      _fail('Hot restart failed', error);
    }
  }

  Future<void> stop() async {
    if (!canStop || session == null) return;

    try {
      await client.stop(session!.id);
    } catch (error) {
      _fail('Stop failed', error);
    }
  }

  void clearConsole() {
    if (logs.isEmpty) return;
    logs.clear();
    notifyListeners();
  }

  Future<RunSession> _ensureSession() async {
    final current = session;
    if (current != null) return current;

    _setStatus(RunnerStatus.creating);
    _appendLog('Creating ${client.displayName} session...');

    final created = await client.createSession(
      files: _workspaceFiles(),
    );
    session = created;
    _setStatus(created.status);

    await _eventsSubscription?.cancel();
    _eventsSubscription = client
        .watchSession(created.id)
        .listen(_handleEvent, onError: (Object error) {
      _fail('Runner event stream failed', error);
    });

    _appendLog('Runner session ready: ${created.id}');
    return created;
  }

  Map<String, String> _workspaceFiles() {
    return {
      for (final entry in workspace.entries)
        if (entry.isFile) entry.path: entry.content,
    };
  }

  void _handleEvent(RunnerEvent event) {
    if (_disposed) return;

    switch (event.type) {
      case RunnerEventType.status:
        final nextStatus = event.status;
        if (nextStatus != null) {
          _setStatus(nextStatus);
        }
        break;
      case RunnerEventType.log:
        final message = event.message;
        if (message != null) {
          _appendLog(message);
        }
        break;
      case RunnerEventType.session:
        final nextSession = event.session;
        if (nextSession != null) {
          session = nextSession;
          status = nextSession.status;
          notifyListeners();
        }
        break;
    }
  }

  void _setStatus(RunnerStatus value) {
    status = value;
    final current = session;
    if (current != null) {
      session = current.copyWith(
        status: value,
        lastActivityAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void _appendLog(String message) {
    logs.add(message);
    notifyListeners();
  }

  void _fail(String action, Object error) {
    status = RunnerStatus.error;
    final current = session;
    if (current != null) {
      session = current.copyWith(
        status: RunnerStatus.error,
        lastActivityAt: DateTime.now(),
      );
    }
    logs.add('$action: $error');
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_eventsSubscription?.cancel());
    final current = session;
    if (current != null) {
      unawaited(client.disposeSession(current.id));
    }
    super.dispose();
  }
}
