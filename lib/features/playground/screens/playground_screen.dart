import 'package:flutter/material.dart';

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
  late final PlaygroundController controller;

  @override
  void initState() {
    super.initState();
    controller = PlaygroundController()..addListener(_refresh);
  }

  @override
  void dispose() {
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
                  length: 3,
                  child: Builder(
                    builder: (tabContext) => CompactPlaygroundLayout(
                      controller: controller,
                      toolbar: PlaygroundToolbar(
                        controller: controller,
                        compact: true,
                        onRun: () {
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
                toolbar: PlaygroundToolbar(controller: controller),
              );
            },
          ),
        ),
      );
}
