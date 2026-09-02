import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../workspace/controllers/workspace_controller.dart';
import '../../workspace/models/workspace_change.dart';
import '../models/export_manifest.dart';
import '../models/workspace_export_bundle.dart';

class WorkspaceExportService {
  const WorkspaceExportService();

  WorkspaceExportBundle build(
    WorkspaceController workspace, {
    DateTime? exportedAt,
  }) {
    final changes = workspace.changes;
    final changedPayloadPaths = <String>{};

    for (final change in changes) {
      if (change.type == WorkspaceChangeType.created ||
          change.type == WorkspaceChangeType.modified) {
        final entry = workspace.entryAt(change.path);
        if (entry != null && entry.isFile) {
          changedPayloadPaths.add(change.path);
        }
      }
    }

    final payloadFiles = changedPayloadPaths.toList()..sort();
    final manifest = ExportManifest(
      exportedAt: exportedAt ?? DateTime.now(),
      changes: changes,
      payloadFiles: payloadFiles,
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

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode workspace export archive.');
    }

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

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(
      ArchiveFile(path, bytes.length, bytes),
    );
  }
}
