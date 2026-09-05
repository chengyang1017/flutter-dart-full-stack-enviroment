import 'workspace_entry.dart';

class WorkspaceSnapshot {
  const WorkspaceSnapshot({
    required this.entries,
    required this.baseEntries,
    required this.openFiles,
    required this.activePath,
    required this.nextId,
    required this.savedAt,
    this.formatVersion = currentFormatVersion,
  });

  static const currentFormatVersion = 1;

  final int formatVersion;
  final List<WorkspaceEntry> entries;
  final List<WorkspaceEntry> baseEntries;
  final List<String> openFiles;
  final String activePath;
  final int nextId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'formatVersion': formatVersion,
        'entries': entries.map(_entryToJson).toList(growable: false),
        'baseEntries': baseEntries.map(_entryToJson).toList(growable: false),
        'openFiles': openFiles,
        'activePath': activePath,
        'nextId': nextId,
        'savedAt': savedAt.toUtc().toIso8601String(),
      };

  factory WorkspaceSnapshot.fromJson(Map<dynamic, dynamic> json) {
    final version = json['formatVersion'];
    if (version != currentFormatVersion) {
      throw FormatException('Unsupported workspace snapshot version: $version');
    }

    final entries = _readEntries(json['entries']);
    final baseEntries = _readEntries(json['baseEntries']);
    final rawOpenFiles = json['openFiles'];
    final openFiles = rawOpenFiles is Iterable
        ? rawOpenFiles.whereType<String>().toList(growable: false)
        : const <String>[];

    final activePath = json['activePath'];
    final nextId = json['nextId'];
    final savedAt = json['savedAt'];

    return WorkspaceSnapshot(
      entries: entries,
      baseEntries: baseEntries,
      openFiles: openFiles,
      activePath: activePath is String ? activePath : '',
      nextId: nextId is int && nextId > 0 ? nextId : 1,
      savedAt: savedAt is String
          ? DateTime.tryParse(savedAt)?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  static Map<String, dynamic> _entryToJson(WorkspaceEntry entry) =>
      <String, dynamic>{
        'id': entry.id,
        'path': entry.path,
        'type': entry.isDirectory ? 'directory' : 'file',
        'content': entry.content,
      };

  static List<WorkspaceEntry> _readEntries(dynamic value) {
    if (value is! Iterable) {
      throw const FormatException('Workspace snapshot entries are missing.');
    }

    return value.map((dynamic item) {
      if (item is! Map) {
        throw const FormatException('Invalid workspace snapshot entry.');
      }

      final id = item['id'];
      final path = item['path'];
      final type = item['type'];
      final content = item['content'];

      if (id is! String || path is! String) {
        throw const FormatException('Workspace entry id/path is invalid.');
      }

      return WorkspaceEntry(
        id: id,
        path: path,
        type: switch (type) {
          'directory' => WorkspaceEntryType.directory,
          'file' => WorkspaceEntryType.file,
          _ => throw FormatException('Unknown workspace entry type: $type'),
        },
        content: content is String ? content : '',
      );
    }).toList(growable: false);
  }
}
