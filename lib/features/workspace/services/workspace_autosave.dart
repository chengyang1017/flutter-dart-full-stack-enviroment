import 'dart:async';

import '../controllers/workspace_controller.dart';
import '../models/workspace_snapshot.dart';
import 'workspace_snapshot_store.dart';

class WorkspaceAutosave {
  WorkspaceAutosave({
    required this.workspace,
    required this.store,
    required this.storageKey,
  }) {
    final saved = store.load(storageKey);
    if (saved != null) {
      workspace.restoreSnapshot(saved);
      restoredSnapshot = true;
    }
    workspace.addListener(_handleWorkspaceChanged);
  }

  final WorkspaceController workspace;
  final WorkspaceSnapshotStore store;
  final String storageKey;

  bool restoredSnapshot = false;
  bool _disposed = false;
  bool _saveRequested = false;
  Future<void>? _saveLoop;

  void _handleWorkspaceChanged() {
    if (_disposed) return;
    _saveRequested = true;
    _saveLoop ??= _drainSaves();
  }

  Future<void> _drainSaves() async {
    try {
      while (_saveRequested && !_disposed) {
        _saveRequested = false;
        final snapshot = workspace.createSnapshot();
        await store.save(storageKey, snapshot);
      }
    } finally {
      _saveLoop = null;
      if (_saveRequested && !_disposed) {
        _saveLoop = _drainSaves();
      }
    }
  }

  Future<void> flush() async {
    if (_disposed) return;
    _saveRequested = true;
    _saveLoop ??= _drainSaves();
    await _saveLoop;
  }

  Future<void> clear() async {
    _saveRequested = false;
    await store.delete(storageKey);
  }

  void dispose() {
    if (_disposed) return;
    workspace.removeListener(_handleWorkspaceChanged);
    final finalSnapshot = workspace.createSnapshot();
    _disposed = true;
    unawaited(store.save(storageKey, finalSnapshot));
  }
}
