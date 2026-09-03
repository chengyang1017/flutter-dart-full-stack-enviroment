import '../controllers/workspace_controller.dart';
import '../models/workspace_git_push.dart';
import '../models/workspace_snapshot.dart';
import 'workspace_git_remote_service.dart';
import 'workspace_project_library.dart';
import 'workspace_remote_persistence.dart';

class WorkspaceGitPushCoordinator {
  WorkspaceGitPushCoordinator({
    required this.workspace,
    required this.projects,
    required this.remote,
    required this.git,
    required String initialCloudRevision,
  }) : _cloudRevision = _validateRevision(initialCloudRevision);

  final WorkspaceController workspace;
  final WorkspaceProjectLibrary projects;
  final WorkspaceRemotePersistence remote;
  final WorkspaceGitRemoteService git;

  String _cloudRevision;

  String get cloudRevision => _cloudRevision;

  Future<WorkspaceGitPushResult> pushCurrent({
    required String commitMessage,
    required String authorName,
    required String authorEmail,
    String? secretName,
    String? username,
  }) async {
    final project = projects.activeProject;
    final binding = project.gitRemote;
    if (binding == null) {
      throw StateError('Workspace has no Git remote binding.');
    }
    final expectedRemoteHead = binding.lastSyncedHead;
    if (expectedRemoteHead == null) {
      throw StateError(
        'Pull the Git remote before the first guarded push so the Workspace '
        'has a trusted remote HEAD.',
      );
    }

    final localSnapshot = workspace.createSnapshot();
    final staged = await remote.saveWorkspace(
      project: project.copyWith(updatedAt: DateTime.now().toUtc()),
      snapshot: localSnapshot,
      expectedRevision: _cloudRevision,
    );
    _cloudRevision = staged.revision;

    final pushed = await git.pushRemote(
      workspaceId: project.id,
      expectedWorkspaceRevision: staged.revision,
      expectedRemoteHead: expectedRemoteHead,
      commitMessage: commitMessage,
      authorName: authorName,
      authorEmail: authorEmail,
      secretName: secretName,
      username: username,
    );
    if (pushed.repositoryUrl != binding.repositoryUrl ||
        pushed.branch != binding.branch ||
        pushed.previousRemoteHead != expectedRemoteHead) {
      throw StateError(
        'Git push result does not match the Workspace remote binding.',
      );
    }

    final baseline = _asCleanBaseline(localSnapshot);
    await projects.snapshotStore.save(project.storageKey, baseline);
    await projects.markGitSyncedHead(project.id, pushed.newRemoteHead);
    workspace.restoreSnapshot(baseline);
    return pushed;
  }

  WorkspaceSnapshot _asCleanBaseline(WorkspaceSnapshot snapshot) {
    return WorkspaceSnapshot(
      formatVersion: snapshot.formatVersion,
      entries: List.of(snapshot.entries),
      baseEntries: List.of(snapshot.entries),
      openFiles: List.of(snapshot.openFiles),
      activePath: snapshot.activePath,
      nextId: snapshot.nextId,
      savedAt: DateTime.now().toUtc(),
      expandedDirectoryIds: List.of(snapshot.expandedDirectoryIds),
      editorStates: Map.of(snapshot.editorStates),
    );
  }

  static String _validateRevision(String value) {
    final source = value.trim();
    if (source.isEmpty) {
      throw ArgumentError('Cloud Workspace revision cannot be empty.');
    }
    return source;
  }
}
