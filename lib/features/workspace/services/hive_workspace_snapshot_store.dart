import 'package:hive/hive.dart';

import '../models/workspace_snapshot.dart';
import 'workspace_snapshot_store.dart';

class HiveWorkspaceSnapshotStore implements WorkspaceSnapshotStore {
  HiveWorkspaceSnapshotStore(this.box);

  final Box<dynamic> box;

  @override
  WorkspaceSnapshot? load(String key) {
    final raw = box.get(key);
    if (raw is! Map) return null;

    try {
      return WorkspaceSnapshot.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(String key, WorkspaceSnapshot snapshot) {
    return box.put(key, snapshot.toJson());
  }

  @override
  Future<void> delete(String key) {
    return box.delete(key);
  }
}
