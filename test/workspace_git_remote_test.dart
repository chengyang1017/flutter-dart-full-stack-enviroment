import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_git_remote.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_project.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_snapshot.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_project_catalog_store.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_project_library.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_snapshot_store.dart';

void main() {
  test('Git remote detects providers and persists without credentials', () {
    final github = WorkspaceGitRemote(
      repositoryUrl: 'https://github.com/chengyang1017/flutter_learining.git',
      branch: 'feature/cloud-workspace',
    );
    expect(github.provider, WorkspaceGitProvider.github);
    expect(github.remoteName, 'origin');

    final restored = WorkspaceGitRemote.fromJson(github.toJson());
    expect(restored.repositoryUrl, github.repositoryUrl);
    expect(restored.branch, 'feature/cloud-workspace');
    expect(restored.provider, WorkspaceGitProvider.github);

    final gitlab = WorkspaceGitRemote(
      repositoryUrl: 'git@gitlab.com:team/project.git',
    );
    expect(gitlab.provider, WorkspaceGitProvider.gitlab);
  });

  test('Git remote rejects embedded credentials and unsafe branch names', () {
    expect(
      () => WorkspaceGitRemote(
        repositoryUrl: 'https://token@github.com/team/project.git',
      ),
      throwsFormatException,
    );
    expect(
      () => WorkspaceGitRemote(
        repositoryUrl: 'ssh://git:password@github.com/team/project.git',
      ),
      throwsFormatException,
    );
    expect(
      () => WorkspaceGitRemote(
        repositoryUrl: 'https://github.com/team/project.git',
        branch: '../main',
      ),
      throwsFormatException,
    );
  });

  test('WorkspaceProject keeps Git binding separate from other metadata', () {
    final now = DateTime.utc(2026, 9, 3);
    final project = WorkspaceProject(
      id: 'workspace-a',
      name: 'Workspace A',
      storageKey: 'workspace:workspace-a',
      kind: WorkspaceProjectKind.practice,
      createdAt: now,
      updatedAt: now,
      gitRemote: WorkspaceGitRemote(
        repositoryUrl: 'https://github.com/team/project.git',
        branch: 'main',
      ),
    );

    final restored = WorkspaceProject.fromJson(project.toJson());
    expect(restored.gitRemote, isNotNull);
    expect(restored.gitRemote!.provider, WorkspaceGitProvider.github);
    expect(restored.gitRemote!.repositoryUrl, contains('github.com/team/project'));
  });

  test('project library binds, persists and removes Git remote', () async {
    final catalog = _MemoryCatalogStore();
    final library = WorkspaceProjectLibrary(
      catalogStore: catalog,
      snapshotStore: _MemorySnapshotStore(),
    );
    final project = await library.createPractice('Git Practice');
    final remote = WorkspaceGitRemote(
      repositoryUrl: 'https://github.com/team/project.git',
      branch: 'develop',
    );

    await library.bindGitRemote(project.id, remote);
    expect(library.projectById(project.id)?.gitRemote?.branch, 'develop');

    final reopened = WorkspaceProjectLibrary(
      catalogStore: catalog,
      snapshotStore: _MemorySnapshotStore(),
    );
    expect(reopened.projectById(project.id)?.gitRemote?.provider,
        WorkspaceGitProvider.github);

    await reopened.unbindGitRemote(project.id);
    expect(reopened.projectById(project.id)?.gitRemote, isNull);

    final reopenedAgain = WorkspaceProjectLibrary(
      catalogStore: catalog,
      snapshotStore: _MemorySnapshotStore(),
    );
    expect(reopenedAgain.projectById(project.id)?.gitRemote, isNull);
  });
}

class _MemoryCatalogStore implements WorkspaceProjectCatalogStore {
  List<WorkspaceProject> projects = <WorkspaceProject>[];
  String? activeProjectId;

  @override
  List<WorkspaceProject> loadProjects() => projects
      .map((project) => WorkspaceProject.fromJson(project.toJson()))
      .toList(growable: false);

  @override
  String? loadActiveProjectId() => activeProjectId;

  @override
  Future<void> saveProjects(List<WorkspaceProject> next) async {
    projects = next
        .map((project) => WorkspaceProject.fromJson(project.toJson()))
        .toList(growable: false);
  }

  @override
  Future<void> saveActiveProjectId(String projectId) async {
    activeProjectId = projectId;
  }
}

class _MemorySnapshotStore implements WorkspaceSnapshotStore {
  final Map<String, WorkspaceSnapshot> values = <String, WorkspaceSnapshot>{};

  @override
  WorkspaceSnapshot? load(String key) => values[key];

  @override
  Future<void> save(String key, WorkspaceSnapshot snapshot) async {
    values[key] = snapshot;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
