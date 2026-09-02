import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_playground/features/workspace/controllers/workspace_controller.dart';
import 'package:flutter_ui_playground/features/workspace/services/dart_frog_workspace_service.dart';

void main() {
  const service = DartFrogWorkspaceService();

  WorkspaceController createWorkspace() {
    return WorkspaceController.flutterPlayground(
      mainDartContent: '''
class PracticeExample {}
const chineseName = '万文社';
const englishName = 'Glyphora';
''',
    );
  }

  test('Dart Frog service adds a runnable backend and Flutter API client', () {
    final workspace = createWorkspace();
    addTearDown(workspace.dispose);

    expect(service.isEnabled(workspace), isFalse);

    service.ensureEnabled(workspace);

    expect(service.isEnabled(workspace), isTrue);
    expect(
      workspace.entryAt(DartFrogWorkspaceService.backendPubspecPath)!.content,
      contains('dart_frog: ^1.2.6'),
    );
    expect(
      workspace.entryAt(DartFrogWorkspaceService.backendRoutePath)!.content,
      contains('Response.json'),
    );
    expect(
      workspace.entryAt(DartFrogWorkspaceService.apiClientPath)!.content,
      contains("String.fromEnvironment('API_URL')"),
    );
    expect(
      workspace.entryAt('pubspec.yaml')!.content,
      contains('http: ^1.6.0'),
    );
    expect(
      workspace.entryAt('lib/main.dart')!.content,
      contains('FullStackPractice'),
    );
  });

  test('enabling Dart Frog twice is idempotent', () {
    final workspace = createWorkspace();
    addTearDown(workspace.dispose);

    service.ensureEnabled(workspace);
    final firstPaths = workspace.entries.map((entry) => entry.path).toList();

    service.ensureEnabled(workspace);
    final secondPaths = workspace.entries.map((entry) => entry.path).toList();

    expect(secondPaths, firstPaths);
    expect(
      RegExp(r'^\s{2}http\s*:', multiLine: true)
          .allMatches(workspace.entryAt('pubspec.yaml')!.content)
          .length,
      1,
    );
  });
}
