import 'dart:io';

import 'package:flutterpractice_cli/flutterpractice_cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await _run(arguments);
  if (code != 0) exitCode = code;
}

Future<int> _run(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help') || arguments.contains('-h')) {
    _printUsage();
    return 0;
  }

  if (arguments.first != 'create') {
    stderr.writeln('Unknown command: ${arguments.first}');
    _printUsage();
    return 64;
  }

  if (arguments.length < 2) {
    stderr.writeln('Missing .flutterpractice package path.');
    _printUsage();
    return 64;
  }

  final packageFile = File(arguments[1]);
  String? outputPath;
  var flutterExecutable = 'flutter';

  for (var index = 2; index < arguments.length; index++) {
    final argument = arguments[index];
    switch (argument) {
      case '--output':
        if (index + 1 >= arguments.length) {
          stderr.writeln('--output requires a new directory path.');
          return 64;
        }
        outputPath = arguments[++index];
        break;
      case '--flutter':
        if (index + 1 >= arguments.length) {
          stderr.writeln('--flutter requires an executable path.');
          return 64;
        }
        flutterExecutable = arguments[++index];
        break;
      default:
        stderr.writeln('Unknown option: $argument');
        return 64;
    }
  }

  if (outputPath == null || outputPath.trim().isEmpty) {
    stderr.writeln('--output is required. The CLI never overwrites a project.');
    return 64;
  }
  if (!await packageFile.exists()) {
    stderr.writeln('Package does not exist: ${packageFile.path}');
    return 66;
  }

  try {
    final creator = FlutterPracticeCreator(
      flutterExecutable: flutterExecutable,
      log: stdout.writeln,
    );
    await creator.create(
      packageBytes: await packageFile.readAsBytes(),
      outputPath: outputPath,
    );
    return 0;
  } on FormatException catch (error) {
    stderr.writeln('Invalid practice package: ${error.message}');
    return 65;
  } on CreateProjectException catch (error) {
    stderr.writeln(error.message);
    return 1;
  } catch (error) {
    stderr.writeln('Unable to create Flutter project: $error');
    return 1;
  }
}

void _printUsage() {
  stdout.writeln('''
flutterpractice

Create a brand-new local Flutter project from a portable practice package.
Existing target directories are never overwritten.

Usage:
  flutterpractice create <file.flutterpractice> --output <new-directory>

Options:
  --output <path>      New project directory. Must not already exist.
  --flutter <path>     Flutter executable to use. Defaults to "flutter".
  -h, --help           Show this help.
''');
}
