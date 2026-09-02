import 'package:flutter/material.dart';

import '../../playground/controllers/playground_controller.dart';
import '../../playground/widgets/preview_panel.dart';
import '../controllers/flutter_runner_controller.dart';
import '../models/run_session.dart';
import 'runner_preview_host.dart';

class RunnerPreviewPanel extends StatelessWidget {
  const RunnerPreviewPanel({
    super.key,
    required this.playground,
    required this.runner,
  });

  final PlaygroundController playground;
  final FlutterRunnerController runner;

  @override
  Widget build(BuildContext context) {
    final previewUrl = runner.previewUrl;
    final showRealPreview = !runner.isMock &&
        previewUrl != null &&
        runner.status == RunnerStatus.running;

    return Column(
      children: [
        if (!runner.isMock)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  showRealPreview
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_queue_outlined,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    showRealPreview
                        ? '真实 Flutter SDK 预览 · ${runner.status.label}'
                        : '真实 Runner · ${runner.status.label} · 等待 Preview 就绪',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: showRealPreview
              ? buildRunnerPreviewHost(previewUrl)
              : PreviewPanel(controller: playground),
        ),
      ],
    );
  }
}
