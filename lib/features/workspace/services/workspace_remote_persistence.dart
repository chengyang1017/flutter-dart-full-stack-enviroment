import '../models/workspace_project.dart';
import '../models/workspace_remote_models.dart';
import '../models/workspace_snapshot.dart';

abstract interface class WorkspaceRemotePersistence {
  Future<WorkspaceRemoteCatalog> loadCatalog();

  Future<WorkspaceRemoteDocument?> loadWorkspace(String workspaceId);

  Future<WorkspaceRemoteDocument> createWorkspace({
    required WorkspaceProject project,
    required WorkspaceSnapshot snapshot,
  });

  Future<WorkspaceRemoteDocument> saveWorkspace({
    required WorkspaceProject project,
    required WorkspaceSnapshot snapshot,
    required String expectedRevision,
  });

  Future<WorkspaceRemoteCatalog> deleteWorkspace({
    required String workspaceId,
    required String expectedRevision,
  });
}
