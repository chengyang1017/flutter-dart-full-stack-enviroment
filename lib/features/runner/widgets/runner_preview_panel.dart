import 'package:flutter/material.dart';

import '../../playground/controllers/playground_controller.dart';
import '../../playground/widgets/preview_panel.dart';
import '../controllers/flutter_runner_controller.dart';
import '../models/run_session.dart';
import '../models/runner_preview_target.dart';
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
    final target = runner.previewTarget;
    final dimensions = target.viewportDimensionsFor(runner.previewOrientation);
    final targetSummary = target.opensExternalTab
        ? target.label
        : '${target.label}视口 · $dimensions · ${runner.previewOrientation.label}';

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
                        ? '真实 Flutter SDK · $targetSummary · ${runner.status.label}'
                        : '真实 Runner · $targetSummary · ${runner.status.label} · 等待 Preview 就绪',
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
              ? target.opensExternalTab
                  ? const _ExternalWebPreview()
                  : _EmbeddedDevicePreview(
                      url: previewUrl,
                      target: target,
                      orientation: runner.previewOrientation,
                      onOrientationChanged: runner.selectPreviewOrientation,
                    )
              : PreviewPanel(controller: playground),
        ),
      ],
    );
  }
}

class RunnerViewportControls extends StatelessWidget {
  const RunnerViewportControls({
    super.key,
    required this.target,
    required this.orientation,
    required this.onOrientationChanged,
  });

  final RunnerPreviewTarget target;
  final RunnerPreviewOrientation orientation;
  final ValueChanged<RunnerPreviewOrientation> onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    final dimensions = target.viewportDimensionsFor(orientation)!;
    final icon = target == RunnerPreviewTarget.phone
        ? Icons.phone_android
        : Icons.tablet_mac_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${target.label}视口 · $dimensions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<RunnerPreviewOrientation>(
            key: const ValueKey('real-run-orientation-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: RunnerPreviewOrientation.portrait,
                icon: Icon(Icons.stay_current_portrait, size: 16),
                label: Text('竖屏'),
              ),
              ButtonSegment(
                value: RunnerPreviewOrientation.landscape,
                icon: Icon(Icons.stay_current_landscape, size: 16),
                label: Text('横屏'),
              ),
            ],
            selected: {orientation},
            onSelectionChanged: (selection) {
              onOrientationChanged(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _EmbeddedDevicePreview extends StatelessWidget {
  const _EmbeddedDevicePreview({
    required this.url,
    required this.target,
    required this.orientation,
    required this.onOrientationChanged,
  });

  final String url;
  final RunnerPreviewTarget target;
  final RunnerPreviewOrientation orientation;
  final ValueChanged<RunnerPreviewOrientation> onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    final width = target.viewportWidthFor(orientation)!;
    final height = target.viewportHeightFor(orientation)!;
    final radius = target == RunnerPreviewTarget.phone ? 28.0 : 20.0;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          RunnerViewportControls(
            target: target,
            orientation: orientation,
            onOrientationChanged: onOrientationChanged,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  key: const ValueKey('real-run-device-fitted-box'),
                  fit: BoxFit.contain,
                  child: SizedBox(
                    key: const ValueKey('real-run-device-viewport'),
                    width: width,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius - 2),
                        child: buildRunnerPreviewHost(url),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalWebPreview extends StatelessWidget {
  const _ExternalWebPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 42),
            const SizedBox(height: 12),
            Text(
              '网页预览使用独立浏览器标签页',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '运行完成后会自动打开。若浏览器阻止新标签页，请允许本站打开弹窗后重新运行。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
