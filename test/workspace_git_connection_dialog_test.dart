import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_git_remote.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_git_remote_check.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_project.dart';
import 'package:flutter_ui_playground/features/workspace/models/workspace_secret.dart';
import 'package:flutter_ui_playground/features/workspace/services/workspace_git_connection_coordinator.dart';
import 'package:flutter_ui_playground/features/workspace/widgets/workspace_git_connection_dialog.dart';

void main() {
  late WorkspaceProject project;

  setUp(() {
    final now = DateTime.utc(2026, 9, 3);
    project = WorkspaceProject(
      id: 'workspace-1',
      name: 'Flutter Practice',
      storageKey: 'workspace:1',
      kind: WorkspaceProjectKind.practice,
      lifecycle: WorkspaceLifecycle.saved,
      createdAt: now,
      updatedAt: now,
      gitRemote: WorkspaceGitRemote(
        repositoryUrl: 'https://github.com/team/app.git',
        branch: 'main',
      ),
    );
  });

  testWidgets('existing Git secret can be selected and checked', (tester) async {
    String? checkedSecretName;
    String? checkedSecretValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => WorkspaceGitConnectionDialog(
                  project: project,
                  loadSecrets: () async => [_secret('GITHUB_TOKEN')],
                  checkConnection: ({secretName, secretValue, username}) async {
                    checkedSecretName = secretName;
                    checkedSecretValue = secretValue;
                    return const WorkspaceGitConnectionCheck(
                      result: WorkspaceGitRemoteCheckResult(
                        repositoryUrl: 'https://github.com/team/app.git',
                        branch: 'main',
                        provider: 'github',
                        reachable: true,
                        branchFound: true,
                        remoteHead: 'aaaaaaaaaaaaaaaa',
                      ),
                    );
                  },
                  onEditRemote: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('workspace-git-secret-GITHUB_TOKEN')));
    await tester.tap(find.byKey(const ValueKey('workspace-git-check')));
    await tester.pumpAndSettle();

    expect(checkedSecretName, 'GITHUB_TOKEN');
    expect(checkedSecretValue, isNull);
    expect(
      find.byKey(const ValueKey('workspace-git-connection-result')),
      findsOneWidget,
    );
    expect(find.textContaining('HEAD: aaaaaaaaaaaaaaaa'), findsOneWidget);
  });

  testWidgets('new token requires a secret name', (tester) async {
    var checkCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => WorkspaceGitConnectionDialog(
                  project: project,
                  loadSecrets: () async => const [],
                  checkConnection: ({secretName, secretValue, username}) async {
                    checkCalls += 1;
                    throw StateError('should not run');
                  },
                  onEditRemote: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('workspace-git-secret-value')),
      'github_pat_example',
    );
    await tester.tap(find.byKey(const ValueKey('workspace-git-check')));
    await tester.pump();

    expect(checkCalls, 0);
    expect(
      find.text('输入 Token 时必须同时填写 Secret name。'),
      findsOneWidget,
    );
  });

  testWidgets('anonymous public repository check passes no credential', (
    tester,
  ) async {
    String? checkedSecretName;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => WorkspaceGitConnectionDialog(
                  project: project,
                  loadSecrets: () async => const [],
                  checkConnection: ({secretName, secretValue, username}) async {
                    checkedSecretName = secretName;
                    return const WorkspaceGitConnectionCheck(
                      result: WorkspaceGitRemoteCheckResult(
                        repositoryUrl: 'https://github.com/team/app.git',
                        branch: 'main',
                        provider: 'github',
                        reachable: true,
                        branchFound: false,
                      ),
                    );
                  },
                  onEditRemote: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-git-check')));
    await tester.pumpAndSettle();

    expect(checkedSecretName, isNull);
    expect(find.textContaining('找不到分支 main'), findsOneWidget);
  });
}

WorkspaceSecretMetadata _secret(String name) {
  final now = DateTime.utc(2026, 9, 3);
  return WorkspaceSecretMetadata(
    name: name,
    contexts: const {WorkspaceSecretContext.git},
    createdAt: now,
    updatedAt: now,
  );
}
