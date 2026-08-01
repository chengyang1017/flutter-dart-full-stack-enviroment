import 'package:flutter/material.dart';

import '../controllers/playground_controller.dart';
import 'code_editor_panel.dart';
import 'error_panel.dart';
import 'preview_panel.dart';

class WidePlaygroundLayout extends StatelessWidget {
  const WidePlaygroundLayout({
    super.key,
    required this.controller,
    required this.toolbar,
  });

  final PlaygroundController controller;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        key: const ValueKey(
          'wide-playground-layout',
        ),
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Text(
                    'Flutter UI Playground',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 260,
                    child: TabBar(
                      tabs: [
                        Tab(
                          icon: Icon(Icons.code),
                          text: '程式碼',
                        ),
                        Tab(
                          icon: Icon(
                            Icons.phone_android,
                          ),
                          text: '預覽',
                        ),
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
                // 程式碼頁面
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        Expanded(
                          child: CodeEditorPanel(
                            controller: controller,
                          ),
                        ),

                        // 錯誤區最多占整體高度的 20%
                        ErrorPanel(
                          controller: controller,
                          maxHeight:
                              constraints.maxHeight *
                                  0.2,
                        ),
                      ],
                    );
                  },
                ),

                // 預覽頁面
                PreviewPanel(
                  controller: controller,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}