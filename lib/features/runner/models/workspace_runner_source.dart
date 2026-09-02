import '../../workspace/models/workspace_change.dart';

class WorkspaceRunnerSource {
  WorkspaceRunnerSource({
    required Map<String, String> files,
    required List<WorkspaceChange> changes,
    this.remoteRevision,
  })  : files = Map<String, String>.unmodifiable(files),
        changes = List<WorkspaceChange>.unmodifiable(changes);

  final Map<String, String> files;
  final List<WorkspaceChange> changes;

  /// Opaque persisted Workspace revision used to identify the exact source
  /// version that was prepared for the disposable Runner.
  final String? remoteRevision;
}
