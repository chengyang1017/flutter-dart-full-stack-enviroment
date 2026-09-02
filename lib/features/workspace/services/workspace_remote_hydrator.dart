import '../models/workspace_remote_models.dart';
import 'workspace_remote_session_provider.dart';

class WorkspaceRemoteHydrator {
  const WorkspaceRemoteHydrator(this.sessions);

  final WorkspaceRemoteSessionProvider sessions;

  /// Hydrates the cloud Workspace for the current authenticated user.
  ///
  /// A null result means there is no remote auth session. This is distinct
  /// from an authenticated user whose remote catalog is simply empty.
  Future<WorkspaceHydrationResult?> hydrate({
    String? preferredWorkspaceId,
  }) async {
    final remote = await sessions.currentRemote();
    if (remote == null) {
      return null;
    }

    final catalog = await remote.loadCatalog();
    if (catalog.projects.isEmpty) {
      return WorkspaceHydrationResult(
        identity: remote.identity,
        catalog: catalog,
        activeDocument: null,
      );
    }

    final selectedId = catalog.projects.any(
      (project) => project.id == preferredWorkspaceId,
    )
        ? preferredWorkspaceId!
        : catalog.projects.first.id;

    final document = await remote.loadWorkspace(selectedId);
    if (document == null) {
      throw StateError(
        'Remote Workspace catalog references a missing Workspace: $selectedId',
      );
    }
    if (document.project.id != selectedId) {
      throw StateError(
        'Remote Workspace id mismatch: requested $selectedId, '
        'received ${document.project.id}',
      );
    }

    return WorkspaceHydrationResult(
      identity: remote.identity,
      catalog: catalog,
      activeDocument: document,
    );
  }
}
