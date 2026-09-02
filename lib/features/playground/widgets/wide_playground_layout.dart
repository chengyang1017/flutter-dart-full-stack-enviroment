import 'package:flutter/material.dart';

import '../../runner/controllers/flutter_runner_controller.dart';
import '../../runner/widgets/runner_console_panel.dart';
import '../../runner/widgets/runner_preview_panel.dart';
import '../../workspace/widgets/workspace_editor_tabs.dart';
import '../../workspace/widgets/workspace_file_explorer.dart';
import '../controllers/playground_controller.dart';
import 'code_editor_panel.dart';
import 'error_panel.dart';

class WidePlaygroundLayout extends StatelessWidget {
  const WidePlaygroundLayout({
    super.key,
    required this.controller,
    required this.runner,
    required this.toolbar,
  });

  final PlaygroundController controller;
  final FlutterRunnerController runner;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        key: const ValueKey('wide-playground-layout'),
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Flutter Practice Workspace',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 260,
                    child: TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.code), text: '代码'),
                        Tab(icon: Icon(Icons.phone_android), text: '预览'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          toolbar,
          Expanded(
            child: TabBarView(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 980 ? 210 : 250,
                          child: WorkspaceFileExplorer(
                            workspace: controller.workspace,
                            onOpenFile: controller.selectWorkspaceFile,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: Column(
                            children: [
                              WorkspaceEditorTabs(
                                workspace: controller.workspace,
                                onSelect: controller.selectWorkspaceFile,
                                onClose: controller.closeWorkspaceFile,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CodeEditorPanel(controller: controller),
                                ),
                              ),
                              ErrorPanel(
                                controller: controller,
                                maxHeight: constraints.maxHeight * 0.14,
                              ),
                              SizedBox(
                                height: constraints.maxHeight < 650 ? 125 : 165,
                                child: RunnerConsolePanel(runner: runner),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                RunnerPreviewPanel(
                  playground: controller,
                  runner: runner,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
