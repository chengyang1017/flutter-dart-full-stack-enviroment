import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../workspace/controllers/workspace_controller.dart';
import '../models/export_manifest.dart';
import '../models/workspace_export_bundle.dart';

class WorkspaceExportService {
  const WorkspaceExportService();

  WorkspaceExportBundle build(
    WorkspaceController workspace, {
    DateTime? exportedAt,
  }) {
    final changes = workspace.changes;
    final payloadFiles = workspace.entries
        .where((entry) => entry.isFile && _isPortablePath(entry.path))
        .map((entry) => entry.path)
        .toList()
      ..sort();
    final projectType = _projectType(workspace);
    final manifest = ExportManifest(
      exportedAt: exportedAt ?? DateTime.now(),
      changes: changes,
      payloadFiles: payloadFiles,
      projectType: projectType,
      template: 'flutter-playground',
    );

    final archive = Archive();
    _addTextFile(
      archive,
      'manifest.json',
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );

    for (final path in payloadFiles) {
      final entry = workspace.entryAt(path);
      if (entry == null || !entry.isFile) continue;
      _addTextFile(archive, path, entry.content);
    }

    final encoded = ZipEncoder().encodeBytes(archive);
    final stamp = manifest.exportedAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return WorkspaceExportBundle(
      fileName: 'flutter-practice-$stamp.flutterpractice',
      bytes: Uint8List.fromList(encoded),
      manifest: manifest,
    );
  }

  bool _isPortablePath(String path) {
    const generatedRoots = <String>{
      '.dart_tool',
      '.git',
      '.gradle',
      '.idea',
      'android',
      'build',
      'coverage',
      'ios',
      'linux',
      'macos',
      'web',
      'windows',
    };
    const generatedRootFiles = <String>{
      '.metadata',
      '.packages',
      '.flutter-plugins',
      '.flutter-plugins-dependencies',
    };

    if (generatedRootFiles.contains(path)) return false;
    final firstSegment = path.split('/').first;
    return !generatedRoots.contains(firstSegment);
  }

  String _projectType(WorkspaceController workspace) {
    final hasServerpod = workspace.entryAt(
              'serverpod/practice_server/config/generator.yaml',
            )
            ?.isFile ==
        true;
    if (hasServerpod) return 'flutter-serverpod-mini';

    final hasDartFrog =
        workspace.entryAt('backend/pubspec.yaml')?.isFile == true &&
            workspace.entries.any(
              (entry) =>
                  entry.isFile &&
                  entry.path.startsWith('backend/routes/') &&
                  entry.path.endsWith('.dart'),
            );
    if (hasDartFrog) return 'flutter-dart-frog';

    return 'flutter';
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }
}
