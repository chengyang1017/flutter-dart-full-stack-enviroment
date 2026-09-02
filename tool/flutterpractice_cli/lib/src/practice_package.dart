import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class FlutterPracticePackage {
  const FlutterPracticePackage({
    required this.formatVersion,
    required this.projectType,
    required this.template,
    required this.projectName,
    required this.files,
  });

  final int formatVersion;
  final String projectType;
  final String template;
  final String projectName;
  final Map<String, String> files;

  static const supportedProjectTypes = <String>{
    'flutter',
    'flutter-dart-frog',
    'flutter-serverpod-mini',
  };

  factory FlutterPracticePackage.decode(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Unable to read .flutterpractice package.');
    }

    final manifests = archive.files.where(
      (file) => file.isFile && file.name == 'manifest.json',
    );
    if (manifests.length != 1) {
      throw const FormatException(
        'Package must contain exactly one manifest.json.',
      );
    }

    final manifestValue = jsonDecode(
      utf8.decode(_bytesOf(manifests.single), allowMalformed: false),
    );
    if (manifestValue is! Map) {
      throw const FormatException('manifest.json must be a JSON object.');
    }
    final manifest = Map<String, dynamic>.from(manifestValue);

    final formatVersion = manifest['formatVersion'];
    final projectType = manifest['projectType'];
    final template = manifest['template'];
    final rawPayloadFiles = manifest['payloadFiles'];

    if (formatVersion != 1) {
      throw FormatException(
        'Unsupported .flutterpractice format version: $formatVersion',
      );
    }
    if (projectType is! String ||
        !supportedProjectTypes.contains(projectType)) {
      throw FormatException('Unsupported project type: $projectType');
    }
    if (template != 'flutter-playground') {
      throw const FormatException(
        'Package does not use the Flutter practice workspace template.',
      );
    }
    if (rawPayloadFiles is! List) {
      throw const FormatException('manifest payloadFiles must be a list.');
    }
    if (rawPayloadFiles.any((value) => value is! String)) {
      throw const FormatException('manifest payloadFiles must contain strings.');
    }

    final payloadFiles = rawPayloadFiles.cast<String>();
    if (payloadFiles.toSet().length != payloadFiles.length) {
      throw const FormatException('manifest payloadFiles contains duplicates.');
    }

    final files = <String, String>{};
    for (final path in payloadFiles) {
      _validatePortablePath(path);
      final matches = archive.files.where(
        (file) => file.isFile && file.name == path,
      );
      if (matches.length != 1) {
        throw FormatException('Missing or duplicate payload file: $path');
      }
      try {
        files[path] = utf8.decode(
          _bytesOf(matches.single),
          allowMalformed: false,
        );
      } on FormatException {
        throw FormatException('Payload file is not UTF-8 text: $path');
      }
    }

    if (!files.containsKey('pubspec.yaml') ||
        !files.containsKey('lib/main.dart')) {
      throw const FormatException(
        'Package must contain pubspec.yaml and lib/main.dart.',
      );
    }

    final projectName = _readProjectName(files['pubspec.yaml']!);
    return FlutterPracticePackage(
      formatVersion: formatVersion,
      projectType: projectType,
      template: template as String,
      projectName: projectName,
      files: Map.unmodifiable(files),
    );
  }

  static String _readProjectName(String pubspec) {
    final match = RegExp(
      r'^\s*name\s*:\s*([a-z][a-z0-9_]*)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null) {
      throw const FormatException(
        'pubspec.yaml must contain a valid Dart package name.',
      );
    }
    return match.group(1)!;
  }

  static void _validatePortablePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.contains('\\')) {
      throw FormatException('Invalid portable workspace path: $path');
    }
    if (RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      throw FormatException('Absolute paths are not allowed: $path');
    }

    final segments = path.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw FormatException('Unsafe portable workspace path: $path');
    }

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

    if (generatedRoots.contains(segments.first) ||
        generatedRootFiles.contains(path)) {
      throw FormatException(
        'Generated/runtime files are not allowed in a practice package: $path',
      );
    }
  }

  static List<int> _bytesOf(ArchiveFile file) => file.content;
}
