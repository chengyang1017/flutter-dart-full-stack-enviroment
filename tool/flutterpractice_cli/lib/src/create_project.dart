import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'practice_package.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

class FlutterPracticeCreator {
  FlutterPracticeCreator({
    this.flutterExecutable = 'flutter',
    ProcessRunner? processRunner,
    void Function(String message)? log,
  })  : _processRunner = processRunner ?? _defaultProcessRunner,
        _log = log ?? _ignoreLog;

  final String flutterExecutable;
  final ProcessRunner _processRunner;
  final void Function(String message) _log;

  Future<Directory> create({
    required Uint8List packageBytes,
    required String outputPath,
  }) async {
    final practicePackage = FlutterPracticePackage.decode(packageBytes);
    final target = Directory(p.normalize(p.absolute(outputPath)));

    if (await target.exists()) {
      throw CreateProjectException(
        'Target directory already exists: ${target.path}',
      );
    }
    final parent = target.parent;
    if (!await parent.exists()) {
      throw CreateProjectException(
        'Target parent directory does not exist: ${parent.path}',
      );
    }

    try {
      _log('Creating a new Flutter scaffold at ${target.path}');
      await _runChecked(
        flutterExecutable,
        [
          'create',
          '--no-pub',
          '--project-name',
          practicePackage.projectName,
          target.path,
        ],
        action: 'flutter create',
      );

      await _removeGeneratedPortableArea(target);
      await _restorePortableFiles(target, practicePackage.files);

      _log('Resolving Flutter dependencies...');
      await _runChecked(
        flutterExecutable,
        const ['pub', 'get'],
        workingDirectory: target.path,
        action: 'flutter pub get',
      );

      if (practicePackage.projectType != 'flutter') {
        _log(
          'Backend source was restored for ${practicePackage.projectType}. '
          'Framework-specific generation can be run from the new project.',
        );
      }
      _log('Created new Flutter project: ${target.path}');
      return target;
    } catch (error) {
      if (await target.exists()) {
        try {
          await target.delete(recursive: true);
        } catch (_) {
          // Preserve the original creation error.
        }
      }
      rethrow;
    }
  }

  Future<void> _removeGeneratedPortableArea(Directory target) async {
    for (final name in const ['lib', 'test']) {
      final directory = Directory(p.join(target.path, name));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    for (final name in const ['pubspec.yaml', 'analysis_options.yaml']) {
      final file = File(p.join(target.path, name));
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _restorePortableFiles(
    Directory target,
    Map<String, String> files,
  ) async {
    for (final entry in files.entries) {
      final destination = File(
        p.joinAll([target.path, ...entry.key.split('/')]),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsString(entry.value, flush: true);
    }
  }

  Future<void> _runChecked(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required String action,
  }) async {
    final result = await _processRunner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    if (result.exitCode == 0) return;

    final stderrText = '${result.stderr}'.trim();
    final stdoutText = '${result.stdout}'.trim();
    final detail = stderrText.isNotEmpty ? stderrText : stdoutText;
    throw CreateProjectException(
      detail.isEmpty
          ? '$action failed with exit code ${result.exitCode}.'
          : '$action failed with exit code ${result.exitCode}: $detail',
    );
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
  }

  static void _ignoreLog(String _) {}
}

class CreateProjectException implements Exception {
  const CreateProjectException(this.message);

  final String message;

  @override
  String toString() => message;
}
