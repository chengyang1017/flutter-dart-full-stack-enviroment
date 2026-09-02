import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_playground/features/runner/models/runner_preview_target.dart';
import 'package:flutter_ui_playground/features/runner/widgets/runner_preview_panel.dart';
import 'package:flutter_ui_playground/features/runner/widgets/runner_target_dialog.dart';

void main() {
  test('real run targets define phone and tablet portrait viewports', () {
    expect(RunnerPreviewTarget.phone.viewportWidth, 390);
    expect(RunnerPreviewTarget.phone.viewportHeight, 844);
    expect(RunnerPreviewTarget.tablet.viewportWidth, 820);
    expect(RunnerPreviewTarget.tablet.viewportHeight, 1180);
    expect(RunnerPreviewTarget.web.viewportWidth, isNull);
    expect(RunnerPreviewTarget.web.viewportHeight, isNull);
    expect(RunnerPreviewTarget.web.opensExternalTab, isTrue);
  });

  test('landscape swaps viewport width and height without changing target', () {
    expect(
      RunnerPreviewTarget.phone.viewportDimensionsFor(
        RunnerPreviewOrientation.portrait,
      ),
      '390 × 844',
    );
    expect(
      RunnerPreviewTarget.phone.viewportDimensionsFor(
        RunnerPreviewOrientation.landscape,
      ),
      '844 × 390',
    );
    expect(
      RunnerPreviewTarget.tablet.viewportDimensionsFor(
        RunnerPreviewOrientation.portrait,
      ),
      '820 × 1180',
    );
    expect(
      RunnerPreviewTarget.tablet.viewportDimensionsFor(
        RunnerPreviewOrientation.landscape,
      ),
      '1180 × 820',
    );
    expect(
      RunnerPreviewTarget.web.viewportDimensionsFor(
        RunnerPreviewOrientation.landscape,
      ),
      isNull,
    );
  });

  testWidgets('run target dialog offers phone tablet and web', (tester) async {
    RunnerPreviewTarget? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => RunnerTargetDialog(
                    onSelected: (target) => selected = target,
                  ),
                );
              },
              child: const Text('Run'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    expect(find.text('选择运行设备'), findsOneWidget);
    expect(find.byKey(const ValueKey('runner-target-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('runner-target-tablet')), findsOneWidget);
    expect(find.byKey(const ValueKey('runner-target-web')), findsOneWidget);
    expect(find.text('手机'), findsOneWidget);
    expect(find.text('平板'), findsOneWidget);
    expect(find.text('网页'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('runner-target-tablet')));
    await tester.pumpAndSettle();

    expect(selected, RunnerPreviewTarget.tablet);
    expect(find.text('选择运行设备'), findsNothing);
  });

  testWidgets('viewport controls show dimensions and select landscape', (
    tester,
  ) async {
    RunnerPreviewOrientation? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunnerViewportControls(
            target: RunnerPreviewTarget.phone,
            orientation: RunnerPreviewOrientation.portrait,
            onOrientationChanged: (orientation) => selected = orientation,
          ),
        ),
      ),
    );

    expect(find.text('手机视口 · 390 × 844'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('real-run-orientation-selector')),
      findsOneWidget,
    );

    await tester.tap(find.text('横屏'));
    await tester.pump();

    expect(selected, RunnerPreviewOrientation.landscape);
  });
}
