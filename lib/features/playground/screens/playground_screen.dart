import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../runner/controllers/flutter_runner_controller.dart';
import '../../runner/services/http_flutter_runner_client.dart';
import '../../runner/services/mock_flutter_runner_client.dart';
import '../../workspace/services/hive_workspace_snapshot_store.dart';
import '../controllers/playground_controller.dart';
import '../widgets/compact_playground_layout.dart';
import '../widgets/playground_toolbar.dart';
import '../widgets/wide_playground_layout.dart';

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  static const _runnerApiUrl = String.fromEnvironment('RUNNER_API_URL');
  static const _workspaceBoxName = 'workspace_snapshots';

  late final PlaygroundController controller;
  late final FlutterRunnerController runner;

  @override
  void initState() {
    super.initState();
    final workspaceStore = Hive.isBoxOpen(_workspaceBoxName)
        ? HiveWorkspaceSnapshotStore(Hive.box<dynamic>(_workspaceBoxName))
        : null;
    controller = PlaygroundController(workspaceStore: workspaceStore)
      ..addListener(_refresh);
    runner = FlutterRunnerController(
      workspace: controller.workspace,
      client: _runnerApiUrl.isEmpty
          ? MockFlutterRunnerClient()
          : HttpFlutterRunnerClient(baseUrl: _runnerApiUrl),
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    runner.removeListener(_refresh);
    runner.dispose();
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 700;
              if (isCompact) {
                return DefaultTabController(
                  length: 4,
                  child: Builder(
                    builder: (tabContext) => CompactPlaygroundLayout(
                      controller: controller,
                      runner: runner,
                      toolbar: PlaygroundToolbar(
                        controller: controller,
                        runner: runner,
                        compact: true,
                        onRun: () async {
                          await runner.run();
                          if (tabContext.mounted) {
                            DefaultTabController.of(tabContext).animateTo(1);
                          }
                        },
                        onQuickPreview: () {
                          controller.runCode();
                          DefaultTabController.of(tabContext).animateTo(1);
                        },
                      ),
                    ),
                  ),
                );
              }
              return WidePlaygroundLayout(
                controller: controller,
                runner: runner,
                toolbar: PlaygroundToolbar(
                  controller: controller,
                  runner: runner,
                ),
              );
            },
          ),
        ),
      );
}
