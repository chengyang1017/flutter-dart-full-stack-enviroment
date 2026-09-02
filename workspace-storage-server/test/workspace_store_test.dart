import 'dart:io';

import 'package:test/test.dart';
import 'package:workspace_storage_server/workspace_storage_server.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('workspace-store-test-');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('persists source documents and isolates users', () async {
    final store = FileWorkspaceStore(temp);
    final created = await store.createWorkspace(
      userId: 'alice',
      project: _project('workspace-a'),
      snapshot: _snapshot('first'),
    );

    expect(created['revision'], 'r1');
    expect((created['snapshot'] as Map)['marker'], 'first');
    expect(
      (await store.loadCatalog('alice'))['revision'],
      'c1',
    );
    expect(
      (await store.loadCatalog('bob'))['projects'],
      isEmpty,
    );
    expect(await store.loadWorkspace('bob', 'workspace-a'), isNull);

    final reopened = FileWorkspaceStore(temp);
    final restored = await reopened.loadWorkspace('alice', 'workspace-a');
    expect(restored, isNotNull);
    expect((restored!['snapshot'] as Map)['marker'], 'first');
  });

  test('save uses optimistic revisions and delete updates catalog', () async {
    final store = FileWorkspaceStore(temp);
    await store.createWorkspace(
      userId: 'alice',
      project: _project('workspace-a'),
      snapshot: _snapshot('first'),
    );

    final saved = await store.saveWorkspace(
      userId: 'alice',
      workspaceId: 'workspace-a',
      project: _project('workspace-a'),
      snapshot: _snapshot('second'),
      expectedRevision: 'r1',
    );
    expect(saved['revision'], 'r2');

    await expectLater(
      store.saveWorkspace(
        userId: 'alice',
        workspaceId: 'workspace-a',
        project: _project('workspace-a'),
        snapshot: _snapshot('stale'),
        expectedRevision: 'r1',
      ),
      throwsA(
        isA<WorkspaceRevisionMismatch>()
            .having((error) => error.expectedRevision, 'expected', 'r1')
            .having((error) => error.actualRevision, 'actual', 'r2'),
      ),
    );

    final catalog = await store.deleteWorkspace(
      userId: 'alice',
      workspaceId: 'workspace-a',
      expectedRevision: 'r2',
    );
    expect(catalog['revision'], 'c3');
    expect(catalog['projects'], isEmpty);
    expect(await store.loadWorkspace('alice', 'workspace-a'), isNull);
  });
}

Map<String, dynamic> _project(String id) => <String, dynamic>{
      'id': id,
      'name': id,
      'storageKey': 'workspace:$id',
      'kind': 'practice',
      'lifecycle': 'saved',
      'createdAt': '2026-09-03T00:00:00.000Z',
      'updatedAt': '2026-09-03T00:00:00.000Z',
    };

Map<String, dynamic> _snapshot(String marker) => <String, dynamic>{
      'formatVersion': 2,
      'entries': <Object>[],
      'baseEntries': <Object>[],
      'openFiles': <Object>[],
      'activePath': '',
      'nextId': 1,
      'savedAt': '2026-09-03T00:00:00.000Z',
      'expandedDirectoryIds': <Object>[],
      'editorStates': <String, Object?>{},
      'marker': marker,
    };
