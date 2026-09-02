import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_entry.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_identity.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_project.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_remote_models.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_snapshot.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_remote_hydrator.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_remote_persistence.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_remote_session_provider.dart';

void main() {
  test('remote Workspace document round-trips metadata snapshot and revision', () {
    final document = WorkspaceRemoteDocument(
      project: _project('workspace-a'),
      snapshot: _snapshot('A'),
      revision: 'opaque-revision-7',
    );

    final restored = WorkspaceRemoteDocument.fromJson(document.toJson());

    expect(restored.project.id, 'workspace-a');
    expect(restored.snapshot.entries.single.content, 'A');
    expect(restored.revision, 'opaque-revision-7');
  });

  test('signed-out session skips remote hydration', () async {
    final result = await WorkspaceRemoteHydrator(
      const _FakeSessionProvider(null),
    ).hydrate();

    expect(result, isNull);
  });

  test('hydrator loads catalog then only the preferred Workspace', () async {
    final remote = _FakeRemotePersistence(
      identity: _identity('user-a'),
      projects: [_project('workspace-a'), _project('workspace-b')],
      documents: {
        'workspace-a': _document('workspace-a', 'A'),
        'workspace-b': _document('workspace-b', 'B'),
      },
    );

    final result = await WorkspaceRemoteHydrator(
      _FakeSessionProvider(remote),
    ).hydrate(preferredWorkspaceId: 'workspace-b');

    expect(result?.identity.userId, 'user-a');
    expect(result?.activeDocument?.project.id, 'workspace-b');
    expect(remote.loadedWorkspaceIds, ['workspace-b']);
  });

  test('hydrator falls back to first catalog Workspace for stale preference', () async {
    final remote = _FakeRemotePersistence(
      identity: _identity('user-a'),
      projects: [_project('workspace-a'), _project('workspace-b')],
      documents: {
        'workspace-a': _document('workspace-a', 'A'),
        'workspace-b': _document('workspace-b', 'B'),
      },
    );

    final result = await WorkspaceRemoteHydrator(
      _FakeSessionProvider(remote),
    ).hydrate(preferredWorkspaceId: 'deleted-workspace');

    expect(result?.activeDocument?.project.id, 'workspace-a');
    expect(remote.loadedWorkspaceIds, ['workspace-a']);
  });

  test('authenticated empty remote catalog is distinct from signed out', () async {
    final remote = _FakeRemotePersistence(
      identity: _identity('user-a'),
      projects: const [],
      documents: const {},
    );

    final result = await WorkspaceRemoteHydrator(
      _FakeSessionProvider(remote),
    ).hydrate();

    expect(result, isNotNull);
    expect(result?.identity.userId, 'user-a');
    expect(result?.activeDocument, isNull);
    expect(result?.catalog.projects, isEmpty);
    expect(remote.loadedWorkspaceIds, isEmpty);
  });

  test('catalog pointing at a missing remote Workspace fails hydration', () async {
    final remote = _FakeRemotePersistence(
      identity: _identity('user-a'),
      projects: [_project('workspace-a')],
      documents: const {},
    );

    await expectLater(
      WorkspaceRemoteHydrator(_FakeSessionProvider(remote)).hydrate(),
      throwsA(isA<StateError>()),
    );
  });

  test('different authenticated users hydrate isolated Workspace catalogs', () async {
    final aliceRemote = _FakeRemotePersistence(
      identity: _identity('alice'),
      projects: [_project('alice-workspace')],
      documents: {
        'alice-workspace': _document('alice-workspace', 'Alice code'),
      },
    );
    final bobRemote = _FakeRemotePersistence(
      identity: _identity('bob'),
      projects: [_project('bob-workspace')],
      documents: {
        'bob-workspace': _document('bob-workspace', 'Bob code'),
      },
    );

    final aliceResult = await WorkspaceRemoteHydrator(
      _FakeSessionProvider(aliceRemote),
    ).hydrate(preferredWorkspaceId: 'bob-workspace');
    final bobResult = await WorkspaceRemoteHydrator(
      _FakeSessionProvider(bobRemote),
    ).hydrate(preferredWorkspaceId: 'alice-workspace');

    expect(
      aliceResult?.catalog.projects.map((project) => project.id),
      ['alice-workspace'],
    );
    expect(aliceResult?.activeDocument?.project.id, 'alice-workspace');
    expect(await aliceRemote.loadWorkspace('bob-workspace'), isNull);

    expect(
      bobResult?.catalog.projects.map((project) => project.id),
      ['bob-workspace'],
    );
    expect(bobResult?.activeDocument?.project.id, 'bob-workspace');
    expect(await bobRemote.loadWorkspace('alice-workspace'), isNull);
  });
}

WorkspaceIdentity _identity(String userId) => WorkspaceIdentity(userId: userId);

WorkspaceProject _project(String id) {
  final now = DateTime.utc(2026, 9, 3);
  return WorkspaceProject(
    id: id,
    name: id,
    storageKey: 'workspace:$id',
    kind: WorkspaceProjectKind.practice,
    lifecycle: WorkspaceLifecycle.saved,
    createdAt: now,
    updatedAt: now,
  );
}

WorkspaceSnapshot _snapshot(String content) => WorkspaceSnapshot(
      entries: [
        WorkspaceEntry(
          id: 'file-1',
          path: 'lib/main.dart',
          type: WorkspaceEntryType.file,
          content: content,
        ),
      ],
      baseEntries: const [],
      openFiles: const ['lib/main.dart'],
      activePath: 'lib/main.dart',
      nextId: 2,
      savedAt: DateTime.utc(2026, 9, 3),
    );

WorkspaceRemoteDocument _document(String id, String content) =>
    WorkspaceRemoteDocument(
      project: _project(id),
      snapshot: _snapshot(content),
      revision: 'revision-$id',
    );

class _FakeSessionProvider implements WorkspaceRemoteSessionProvider {
  const _FakeSessionProvider(this.remote);

  final WorkspaceRemotePersistence? remote;

  @override
  Future<WorkspaceRemotePersistence?> currentRemote() async => remote;
}

class _FakeRemotePersistence implements WorkspaceRemotePersistence {
  _FakeRemotePersistence({
    required this.identity,
    required List<WorkspaceProject> projects,
    required this.documents,
  }) : catalog = WorkspaceRemoteCatalog(
          projects: projects,
          revision: 'catalog-${identity.userId}',
        );

  @override
  final WorkspaceIdentity identity;

  final WorkspaceRemoteCatalog catalog;
  final Map<String, WorkspaceRemoteDocument> documents;
  final List<String> loadedWorkspaceIds = [];

  @override
  Future<WorkspaceRemoteCatalog> loadCatalog() async => catalog;

  @override
  Future<WorkspaceRemoteDocument?> loadWorkspace(String workspaceId) async {
    loadedWorkspaceIds.add(workspaceId);
    return documents[workspaceId];
  }

  @override
  Future<WorkspaceRemoteDocument> createWorkspace({
    required WorkspaceProject project,
    required WorkspaceSnapshot snapshot,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceRemoteDocument> saveWorkspace({
    required WorkspaceProject project,
    required WorkspaceSnapshot snapshot,
    required String expectedRevision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceRemoteCatalog> deleteWorkspace({
    required String workspaceId,
    required String expectedRevision,
  }) {
    throw UnimplementedError();
  }
}
