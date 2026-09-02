import '../../workspace/models/workspace_change.dart';

class ExportManifest {
  const ExportManifest({
    required this.exportedAt,
    required this.changes,
    required this.payloadFiles,
    this.formatVersion = 1,
    this.projectType = 'flutter',
    this.template = 'flutter-playground',
  });

  factory ExportManifest.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    final rawPayloadFiles = json['payloadFiles'];

    if (rawChanges is! List || rawPayloadFiles is! List) {
      throw const FormatException('Invalid workspace export manifest.');
    }

    return ExportManifest(
      formatVersion: json['formatVersion'] as int? ?? 0,
      projectType: json['projectType'] as String? ?? '',
      template: json['template'] as String? ?? '',
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      changes: rawChanges.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return WorkspaceChange(
          type: WorkspaceChangeType.values.byName(map['type'] as String),
          path: map['path'] as String,
          previousPath: map['previousPath'] as String?,
        );
      }).toList(growable: false),
      payloadFiles: rawPayloadFiles.cast<String>().toList(growable: false),
    );
  }

  final int formatVersion;
  final String projectType;
  final String template;
  final DateTime exportedAt;
  final List<WorkspaceChange> changes;
  final List<String> payloadFiles;

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'projectType': projectType,
        'template': template,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'changes': changes
            .map(
              (change) => <String, Object?>{
                'type': change.type.name,
                'path': change.path,
                if (change.previousPath != null)
                  'previousPath': change.previousPath,
              },
            )
            .toList(growable: false),
        'payloadFiles': payloadFiles,
      };
}
