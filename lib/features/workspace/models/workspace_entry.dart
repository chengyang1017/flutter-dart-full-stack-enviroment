enum WorkspaceEntryType {
  file,
  directory,
}

class WorkspaceEntry {
  const WorkspaceEntry({
    required this.id,
    required this.path,
    required this.type,
    this.content = '',
  });

  final String id;
  final String path;
  final WorkspaceEntryType type;
  final String content;

  bool get isFile => type == WorkspaceEntryType.file;
  bool get isDirectory => type == WorkspaceEntryType.directory;

  String get name {
    final index = path.lastIndexOf('/');
    return index == -1 ? path : path.substring(index + 1);
  }

  String get parentPath {
    final index = path.lastIndexOf('/');
    return index == -1 ? '' : path.substring(0, index);
  }

  WorkspaceEntry copyWith({
    String? path,
    String? content,
  }) {
    return WorkspaceEntry(
      id: id,
      path: path ?? this.path,
      type: type,
      content: content ?? this.content,
    );
  }
}
