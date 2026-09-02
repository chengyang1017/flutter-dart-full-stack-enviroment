import 'package:flutter/material.dart';

import '../../workspace/widgets/workspace_file_explorer.dart';
import '../controllers/playground_controller.dart';
import 'code_editor_panel.dart';
import 'error_panel.dart';
import 'preview_panel.dart';

class CompactPlaygroundLayout extends StatelessWidget {
  const CompactPlaygroundLayout({
    super.key,
    required this.controller,
    required this.toolbar,
  });

  final PlaygroundController controller;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const _TitleBar(),
          toolbar,
          const TabBar(
            tabs: [
              Tab(text: '代码', icon: Icon(Icons.code)),
              Tab(text: '预览', icon: Icon(Icons.phone_android)),
              Tab(text: '文件', icon: Icon(Icons.folder_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _EditorWithErrors(controller: controller),
                PreviewPanel(controller: controller),
                WorkspaceFileExplorer(
                  workspace: controller.workspace,
                  onOpenFile: controller.selectWorkspaceFile,
                ),
              ],
            ),
          ),
        ],
      );
}

class _EditorWithErrors extends StatelessWidget {
  const _EditorWithErrors({required this.controller});
  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(child: CodeEditorPanel(controller: controller)),
            ErrorPanel(
              controller: controller,
              maxHeight: constraints.maxHeight * .3,
            ),
          ],
        ),
      );
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Flutter Practice Workspace',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      );
}
