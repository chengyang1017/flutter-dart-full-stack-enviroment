import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../controllers/playground_controller.dart';
import '../highlighting/flutter_dart_highlight.dart';

class CodeEditorPanel extends StatelessWidget {
  const CodeEditorPanel({
    super.key,
    required this.controller,
  });

  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    final codeFontSize = isCompact ? 15.0 : 16.0;
    final lineNumberFontSize = isCompact ? 13.0 : 14.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xff111318),
        child: CodeEditor(
          controller: controller.textController,

          // 关闭自动换行，长代码使用横向滚动。
          wordWrap: false,

          // 自动补齐括号、引号等符号。
          autocompleteSymbols: true,

          // 暂时关闭代码折叠，优先保证输入稳定。
          chunkAnalyzer: NonCodeChunkAnalyzer(),

          autofocus: false,

          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          onChanged: (_) {
            controller.updateCode();
          },

          style: CodeEditorStyle(
            // Windows 上接近 VS Code 的等宽字体。
            fontFamily: 'Consolas',
            fontFamilyFallback: const [
              'Cascadia Mono',
              'Cascadia Code',
              'Microsoft YaHei',
              'Courier New',
            ],
            fontSize: codeFontSize,
            fontHeight: 1.5,

            textColor: const Color(0xffd6deeb),
            backgroundColor: const Color(0xff111318),

            cursorColor: const Color(0xff82aaff),
            cursorWidth: 2,
            cursorLineColor: const Color(0xff191c23),

            selectionColor: const Color(0xff334b68),
            highlightColor: const Color(0xff3b4252),

            codeTheme: CodeHighlightTheme(
              languages: {
                'dart': CodeHighlightThemeMode(
                  mode: flutterDartMode,
                ),
              },
              theme: vscodeDark2026Theme,
            ),
          ),

          indicatorBuilder: (
            context,
            editingController,
            chunkController,
            notifier,
          ) {
            return DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const [
                  'Cascadia Mono',
                  'Cascadia Code',
                  'Courier New',
                ],
                fontSize: lineNumberFontSize,
                height: 1.5,
                color: const Color(0xff5c6370),
              ),
              focusedTextStyle: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const [
                  'Cascadia Mono',
                  'Cascadia Code',
                  'Courier New',
                ],
                fontSize: lineNumberFontSize,
                height: 1.5,
                color: const Color(0xffabb2bf),
              ),
            );
          },

          leadingDivider: Container(
            width: 1,
            color: const Color(0xff2c313c),
          ),
        ),
      ),
    );
  }
}
