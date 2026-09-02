import 'package:flutter/foundation.dart';

import '../models/workspace_change.dart';
import '../models/workspace_entry.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController._({
    required List<WorkspaceEntry> entries,
    required this.activePath,
  })  : _entries = {for (final entry in entries) entry.id: entry},
        _baseEntries = {for (final entry in entries) entry.id: entry},
        _openFiles = [activePath];

  factory WorkspaceController.flutterPlayground({
    required String mainDartContent,
  }) {
    return WorkspaceController._(
      activePath: 'lib/main.dart',
      entries: [
        const WorkspaceEntry(
          id: 'dir-lib',
          path: 'lib',
          type: WorkspaceEntryType.directory,
        ),
        WorkspaceEntry(
          id: 'file-main',
          path: 'lib/main.dart',
          type: WorkspaceEntryType.file,
          content: mainDartContent,
        ),
        const WorkspaceEntry(
          id: 'dir-assets',
          path: 'assets',
          type: WorkspaceEntryType.directory,
        ),
        const WorkspaceEntry(
          id: 'dir-test',
          path: 'test',
          type: WorkspaceEntryType.directory,
        ),
        const WorkspaceEntry(
          id: 'file-pubspec',
          path: 'pubspec.yaml',
          type: WorkspaceEntryType.file,
          content: '''name: flutter_practice\ndescription: Lightweight Flutter practice workspace.\npublish_to: none\n\nenvironment:\n  sdk: ^3.4.0\n\ndependencies:\n  flutter:\n    sdk: flutter\n\nflutter:\n  uses-material-design: true\n  assets:\n    - assets/\n''',
        ),
        const WorkspaceEntry(
          id: 'file-analysis-options',
          path: 'analysis_options.yaml',
          type: WorkspaceEntryType.file,
          content: 'include: package:flutter_lints/flutter.yaml\n',
        ),
      ],
    );
  }

  final Map<String, WorkspaceEntry> _baseEntries;
  final Map<String, WorkspaceEntry> _entries;
  final List<String> _openFiles;

  int _nextId = 1;
  String activePath;

  List<WorkspaceEntry> get entries {
    final values = _entries.values.toList()
      ..sort((a, b) {
        if (a.parentPath == b.parentPath && a.type != b.type) {
          return a.isDirectory ? -1 : 1;
        }
        return a.path.compareTo(b.path);
      });
    return List.unmodifiable(values);
  }

  List<String> get openFiles => List.unmodifiable(_openFiles);

  WorkspaceEntry? get activeEntry => entryAt(activePath);

  WorkspaceEntry? entryAt(String path) {
    for (final entry in _entries.values) {
      if (entry.path == path) return entry;
    }
    return null;
  }

  bool get isDirty => changes.isNotEmpty;

  bool isFileDirty(String path) {
    final current = entryAt(path);
    if (current == null || !current.isFile) return false;

    final base = _baseEntries[current.id];
    if (base == null) return true;

    return base.path != current.path || base.content != current.content;
  }

  List<WorkspaceChange> get changes {
    final result = <WorkspaceChange>[];

    for (final base in _baseEntries.values) {
      final current = _entries[base.id];
      if (current == null) {
        result.add(
          WorkspaceChange(
            type: WorkspaceChangeType.deleted,
            path: base.path,
          ),
        );
        continue;
      }

      if (base.path != current.path) {
        result.add(
          WorkspaceChange(
            type: base.parentPath == current.parentPath
                ? WorkspaceChangeType.renamed
                : WorkspaceChangeType.moved,
            path: current.path,
            previousPath: base.path,
          ),
        );
      }

      if (current.isFile && base.content != current.content) {
        result.add(
          WorkspaceChange(
            type: WorkspaceChangeType.modified,
            path: current.path,
          ),
        );
      }
    }

    for (final current in _entries.values) {
      if (!_baseEntries.containsKey(current.id)) {
        result.add(
          WorkspaceChange(
            type: WorkspaceChangeType.created,
            path: current.path,
          ),
        );
      }
    }

    result.sort((a, b) => a.path.compareTo(b.path));
    return List.unmodifiable(result);
  }

  List<WorkspaceEntry> childrenOf(String parentPath) {
    final children = _entries.values
        .where((entry) => entry.parentPath == parentPath)
        .toList()
      ..sort((a, b) {
        if (a.type != b.type) return a.isDirectory ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return List.unmodifiable(children);
  }

  void openFile(String path) {
    final entry = entryAt(path);
    if (entry == null || !entry.isFile) return;

    if (!_openFiles.contains(path)) {
      _openFiles.add(path);
    }
    activePath = path;
    notifyListeners();
  }

  void closeFile(String path) {
    final index = _openFiles.indexOf(path);
    if (index == -1) return;

    _openFiles.removeAt(index);
    if (_openFiles.isEmpty) {
      final fallback = _entries.values
          .where((entry) => entry.isFile)
          .map((entry) => entry.path)
          .toList()
        ..sort();
      if (fallback.isNotEmpty) {
        _openFiles.add(fallback.first);
      }
    }

    if (activePath == path && _openFiles.isNotEmpty) {
      final nextIndex = index < _openFiles.length ? index : _openFiles.length - 1;
      activePath = _openFiles[nextIndex];
    }
    notifyListeners();
  }

  void updateFileContent(String path, String content) {
    final entry = entryAt(path);
    if (entry == null || !entry.isFile || entry.content == content) return;

    _entries[entry.id] = entry.copyWith(content: content);
    notifyListeners();
  }

  String createFile(String parentPath, String name, {String content = ''}) {
    final path = _join(parentPath, name);
    _assertCreatablePath(path);
    if (parentPath.isNotEmpty) _assertDirectory(parentPath);

    final entry = WorkspaceEntry(
      id: _newId(),
      path: path,
      type: WorkspaceEntryType.file,
      content: content,
    );
    _entries[entry.id] = entry;
    _openFiles.add(path);
    activePath = path;
    notifyListeners();
    return path;
  }

  String createDirectory(String parentPath, String name) {
    final path = _join(parentPath, name);
    _assertCreatablePath(path);
    if (parentPath.isNotEmpty) _assertDirectory(parentPath);

    final entry = WorkspaceEntry(
      id: _newId(),
      path: path,
      type: WorkspaceEntryType.directory,
    );
    _entries[entry.id] = entry;
    notifyListeners();
    return path;
  }

  void deleteEntry(String path) {
    final entry = entryAt(path);
    if (entry == null) return;

    final removedPaths = _entries.values
        .where((candidate) =>
            candidate.path == path || candidate.path.startsWith('$path/'))
        .map((candidate) => candidate.path)
        .toSet();

    _entries.removeWhere(
      (_, candidate) => removedPaths.contains(candidate.path),
    );
    _openFiles.removeWhere(removedPaths.contains);

    if (removedPaths.contains(activePath)) {
      if (_openFiles.isNotEmpty) {
        activePath = _openFiles.last;
      } else {
        final fallback = _entries.values
            .where((candidate) => candidate.isFile)
            .map((candidate) => candidate.path)
            .toList()
          ..sort();
        if (fallback.isNotEmpty) {
          activePath = fallback.first;
          _openFiles.add(activePath);
        } else {
          activePath = '';
        }
      }
    }
    notifyListeners();
  }

  void renameEntry(String path, String newName) {
    final entry = entryAt(path);
    if (entry == null) return;
    final target = _join(entry.parentPath, newName);
    _movePath(path, target);
  }

  void moveEntry(String path, String newParentPath) {
    final entry = entryAt(path);
    if (entry == null) return;
    if (newParentPath.isNotEmpty) _assertDirectory(newParentPath);

    if (entry.isDirectory &&
        (newParentPath == path || newParentPath.startsWith('$path/'))) {
      throw ArgumentError('Cannot move a directory into itself.');
    }

    final target = _join(newParentPath, entry.name);
    _movePath(path, target);
  }

  void resetFile(String path) {
    final current = entryAt(path);
    if (current == null || !current.isFile) return;
    final base = _baseEntries[current.id];
    if (base == null) {
      deleteEntry(path);
      return;
    }

    final oldPath = current.path;
    _entries[current.id] = base;
    _replaceOpenPath(oldPath, base.path);
    if (activePath == oldPath) activePath = base.path;
    notifyListeners();
  }

  void resetWorkspace() {
    _entries
      ..clear()
      ..addAll(_baseEntries);
    _openFiles
      ..clear()
      ..add('lib/main.dart');
    activePath = 'lib/main.dart';
    notifyListeners();
  }

  void _movePath(String source, String target) {
    if (source == target) return;
    _validatePath(target);

    final affected = _entries.values
        .where((entry) => entry.path == source || entry.path.startsWith('$source/'))
        .toList();
    final affectedIds = affected.map((entry) => entry.id).toSet();

    for (final entry in affected) {
      final suffix = entry.path.substring(source.length);
      final nextPath = '$target$suffix';
      final collision = _entries.values.any(
        (candidate) => !affectedIds.contains(candidate.id) && candidate.path == nextPath,
      );
      if (collision) {
        throw ArgumentError('Path already exists: $nextPath');
      }
    }

    for (final entry in affected) {
      final suffix = entry.path.substring(source.length);
      _entries[entry.id] = entry.copyWith(path: '$target$suffix');
    }

    for (var i = 0; i < _openFiles.length; i++) {
      final open = _openFiles[i];
      if (open == source || open.startsWith('$source/')) {
        _openFiles[i] = '$target${open.substring(source.length)}';
      }
    }

    if (activePath == source || activePath.startsWith('$source/')) {
      activePath = '$target${activePath.substring(source.length)}';
    }
    notifyListeners();
  }

  void _replaceOpenPath(String oldPath, String newPath) {
    final index = _openFiles.indexOf(oldPath);
    if (index != -1) _openFiles[index] = newPath;
  }

  void _assertDirectory(String path) {
    final parent = entryAt(path);
    if (parent == null || !parent.isDirectory) {
      throw ArgumentError('Directory does not exist: $path');
    }
  }

  void _assertCreatablePath(String path) {
    _validatePath(path);
    final collision = _entries.values.any((entry) => entry.path == path);
    if (collision) throw ArgumentError('Path already exists: $path');
  }

  void _validatePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.contains('\\')) {
      throw ArgumentError('Workspace paths must be relative POSIX paths.');
    }
    if (path.split('/').any((segment) =>
        segment.isEmpty || segment == '.' || segment == '..')) {
      throw ArgumentError('Invalid workspace path: $path');
    }
  }

  String _newId() => 'workspace-${_nextId++}';

  String _join(String parent, String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.contains('/') || cleanName.contains('\\')) {
      throw ArgumentError('Name must be a single path segment.');
    }
    return parent.isEmpty ? cleanName : '$parent/$cleanName';
  }
}
