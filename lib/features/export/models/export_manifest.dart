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
