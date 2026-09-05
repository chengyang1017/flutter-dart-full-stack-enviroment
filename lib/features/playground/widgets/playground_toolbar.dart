import 'package:flutter/material.dart';

import '../../export/services/workspace_export_download.dart';
import '../../export/services/workspace_export_service.dart';
import '../../export/services/workspace_import_picker.dart';
import '../../export/services/workspace_import_service.dart';
import '../../runner/controllers/flutter_runner_controller.dart';
import '../../workspace/services/dart_frog_workspace_service.dart';
import '../controllers/playground_controller.dart';
import 'supported_widgets_dialog.dart';

class PlaygroundToolbar extends StatelessWidget {
  const PlaygroundToolbar({
    super.key,
    required this.controller,
    required this.runner,
    this.compact = false,
    this.onRun,
    this.onQuickPreview,
  });

  final PlaygroundController controller;
  final FlutterRunnerController runner;
  final bool compact;
  final VoidCallback? onRun;
  final VoidCallback? onQuickPreview;

  @override
  Widget build(BuildContext context) {
    final density = compact ? VisualDensity.compact : VisualDensity.standard;
    final canExport = controller.workspace.isDirty &&
        supportsWorkspaceExportDownload;
    const dartFrog = DartFrogWorkspaceService();
    final dartFrogEnabled = dartFrog.isEnabled(controller.workspace);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: compact ? 56 : 64,
        child: SingleChildScrollView(
          key: const ValueKey('playground-toolbar-scroll'),
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(visualDensity: density),
                  onPressed: runner.canRun ? (onRun ?? runner.run) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(runner.isMock ? 'Run (Mock)' : 'Run'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('dart-frog-workspace-button'),
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: runner.canRun
                      ? () {
                          dartFrog.ensureEnabled(controller.workspace);
                          controller.selectWorkspaceFile(
                            DartFrogWorkspaceService.backendRoutePath,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.api),
                  label: Text(
                    dartFrogEnabled ? 'Dart Frog' : '+ Dart Frog',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: onQuickPreview ?? controller.runCode,
                  icon: const Icon(Icons.bolt),
                  label: const Text('快速预览'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: runner.canHotReload ? runner.hotReload : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Hot Reload'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: runner.canHotRestart ? runner.hotRestart : null,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Hot Restart'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: runner.canStop ? runner.stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: supportsWorkspaceImportPicker
                      ? () => _importWorkspace(context)
                      : null,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('导入'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: canExport
                      ? () => _exportWorkspace(context)
                      : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出修改'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: controller.clearCode,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: controller.resetExample,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复示例'),
                ),
                const SizedBox(width: 12),
                const Text('自动预览'),
                const SizedBox(width: 4),
                Switch(
                  value: controller.autoRun,
                  onChanged: (_) => controller.toggleAutoRun(),
                ),
                IconButton(
                  tooltip: '深色预览',
                  onPressed: controller.togglePreviewTheme,
                  icon: Icon(
                    controller.darkPreview ? Icons.dark_mode : Icons.light_mode,
                  ),
                ),
                DropdownButton<PreviewDevice>(
                  value: controller.device,
                  onChanged: (value) {
                    if (value != null) controller.changeDevice(value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: PreviewDevice.androidPhone,
                      child: Text('Android Phone'),
                    ),
                    DropdownMenuItem(
                      value: PreviewDevice.smallPhone,
                      child: Text('Small Phone'),
                    ),
                    DropdownMenuItem(
                      value: PreviewDevice.tablet,
                      child: Text('Tablet'),
                    ),
                    DropdownMenuItem(
                      value: PreviewDevice.responsive,
                      child: Text('Responsive'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Quick Preview 支持的组件',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const SupportedWidgetsDialog(),
                  ),
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importWorkspace(BuildContext context) async {
    if (controller.workspace.isDirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入新的练习包？'),
          content: const Text(
            '当前 Workspace 有未导出的修改。导入会先恢复默认模板，再应用练习包里的修改。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续导入'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      final bytes = await pickWorkspaceImport();
      if (bytes == null || !context.mounted) return;

      final manifest = const WorkspaceImportService().apply(
        bytes,
        controller.workspace,
      );
      controller.runCode();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导入 ${manifest.changes.length} 个 Workspace 修改。',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _exportWorkspace(BuildContext context) async {
    try {
      final bundle = const WorkspaceExportService().build(
        controller.workspace,
      );
      await downloadWorkspaceExport(
        bundle.bytes,
        bundle.fileName,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导出 ${bundle.manifest.changes.length} 个修改：${bundle.fileName}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }
}
