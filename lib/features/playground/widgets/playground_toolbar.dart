import 'package:flutter/material.dart';

import '../../export/services/workspace_export_download.dart';
import '../../export/services/workspace_export_service.dart';
import '../../export/services/workspace_import_picker.dart';
import '../../export/services/workspace_import_service.dart';
import '../../export/widgets/export_project_guide_dialog.dart';
import '../../runner/controllers/flutter_runner_controller.dart';
import '../../runner/widgets/dart_frog_api_lab_dialog.dart';
import '../../workspace/services/dart_frog_workspace_service.dart';
import '../../workspace/services/serverpod_workspace_service.dart';
import '../controllers/playground_controller.dart';
import '../../core/editor_enhancements.dart';
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
    final canExport = supportsWorkspaceExportDownload;
    const dartFrog = DartFrogWorkspaceService();
    const serverpod = ServerpodWorkspaceService();
    final dartFrogEnabled = dartFrog.isEnabled(controller.workspace);
    final serverpodEnabled = serverpod.isEnabled(controller.workspace);
    final backendUrl = runner.session?.backendUrl;
    final apiLabUrl = dartFrogEnabled && runner.canHotReload ? backendUrl : null;

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
                      ? () => _enableDartFrog(
                            context,
                            dartFrog,
                            serverpodEnabled: serverpodEnabled,
                          )
                      : null,
                  icon: const Icon(Icons.api),
                  label: Text(
                    dartFrogEnabled ? 'Dart Frog' : '+ Dart Frog',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('serverpod-workspace-button'),
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: runner.canRun
                      ? () => _enableServerpod(
                            context,
                            serverpod,
                            dartFrogEnabled: dartFrogEnabled,
                          )
                      : null,
                  icon: const Icon(Icons.hub_outlined),
                  label: Text(
                    serverpodEnabled ? 'Serverpod' : '+ Serverpod',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('dart-frog-api-lab-button'),
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: apiLabUrl != null
                      ? () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => DartFrogApiLabDialog(
                              baseUrl: apiLabUrl,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.http),
                  label: const Text('API 调试'),
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
                const SizedBox(width: 8),

                // Undo / Redo buttons with keyboard hints and improved UX
                Tooltip(
                  message: controller.canUndo ? '撤销 (Ctrl/Cmd+Z)' : '无可撤销的操作',
                  waitDuration: const Duration(milliseconds: 400),
                  child: IconButton(
                    onPressed: controller.canUndo ? controller.undo : null,
                    icon: Icon(
                      Icons.undo,
                      color: controller.canUndo
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
                Tooltip(
                  message: controller.canRedo ? '重做 (Ctrl+Y / Cmd+Shift+Z)' : '无可重做的操作',
                  waitDuration: const Duration(milliseconds: 400),
                  child: IconButton(
                    onPressed: controller.canRedo ? controller.redo : null,
                    icon: Icon(
                      Icons.redo,
                      color: controller.canRedo
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Tooltip(
                  message: '格式化 (Ctrl/Cmd+Shift+F)',
                  waitDuration: const Duration(milliseconds: 400),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: density,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      disabledForegroundColor: Theme.of(context).disabledColor,
                    ),
                    onPressed: controller.formatCode,
                    icon: const Icon(Icons.format_align_left),
                    label: const Text('格式化'),
                  ),
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
                  key: const ValueKey('export-project-button'),
                  style: OutlinedButton.styleFrom(visualDensity: density),
                  onPressed: canExport
                      ? () => _exportWorkspace(context)
                      : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出项目'),
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
                // 快捷键帮助（? 弹窗）
                Tooltip(
                  message: '快捷键帮助',
                  waitDuration: const Duration(milliseconds: 400),
                  child: IconButton(
                    tooltip: '快捷键帮助',
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('快捷键帮助'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: EditorEnhancements.keyboardShortcuts.entries
                                    .map((entry) => ListTile(
                                          dense: true,
                                          title: Text(entry.key),
                                          trailing: Text(entry.value),
                                        ))
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('关闭'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.keyboard),
                  ),
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

  void _enableDartFrog(
    BuildContext context,
    DartFrogWorkspaceService service, {
    required bool serverpodEnabled,
  }) {
    if (serverpodEnabled) {
      _showFrameworkConflict(
        context,
        current: 'Serverpod',
        requested: 'Dart Frog',
      );
      return;
    }
    try {
      service.ensureEnabled(controller.workspace);
      controller.selectWorkspaceFile(DartFrogWorkspaceService.backendRoutePath);
    } catch (error) {
      _showFrameworkError(context, error);
    }
  }

  void _enableServerpod(
    BuildContext context,
    ServerpodWorkspaceService service, {
    required bool dartFrogEnabled,
  }) {
    if (dartFrogEnabled) {
      _showFrameworkConflict(
        context,
        current: 'Dart Frog',
        requested: 'Serverpod',
      );
      return;
    }
    try {
      service.ensureEnabled(controller.workspace);
      controller.selectWorkspaceFile(
        ServerpodWorkspaceService.greetingEndpointPath,
      );
    } catch (error) {
      _showFrameworkError(context, error);
    }
  }

  void _showFrameworkConflict(
    BuildContext context, {
    required String current,
    required String requested,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '当前 Workspace 已启用 $current。请新建或重置练习后再启用 $requested。',
        ),
      ),
    );
  }

  void _showFrameworkError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('全栈环境创建失败：$error')),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => ExportProjectGuideDialog(
          fileName: bundle.fileName,
          projectType: bundle.manifest.projectType,
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await downloadWorkspaceExport(bundle.bytes, bundle.fileName);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已下载练习包：${bundle.fileName}。它保存的是源码和项目配方，不是完整 Flutter 工程。',
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
