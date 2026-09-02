import 'package:flutter/material.dart';

import '../controllers/playground_controller.dart';
import 'supported_widgets_dialog.dart';

class PlaygroundToolbar extends StatelessWidget {
  const PlaygroundToolbar({
    super.key,
    required this.controller,
    this.compact = false,
    this.onRun,
  });

  final PlaygroundController controller;
  final bool compact;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final density = compact ? VisualDensity.compact : VisualDensity.standard;
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
                  onPressed: onRun ?? controller.runCode,
                  icon: const Icon(Icons.bolt),
                  label: const Text('快速预览'),
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
}
