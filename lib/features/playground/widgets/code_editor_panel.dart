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

  static const _codeFontFamily = 'Consolas';
  static const _codeFontFallback = <String>[
    'Cascadia Mono',
    'Cascadia Code',
    'Courier New',
    'monospace',
    'Microsoft YaHei',
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    // Keep editor metrics close to a desktop IDE. Most importantly, all Latin
    // characters and whitespace should resolve to a monospace font before we
    // fall back to a CJK font, otherwise spaces can look much narrower.
    final codeFontSize = isCompact ? 16.0 : 17.0;
    final lineNumberFontSize = isCompact ? 13.5 : 14.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xff111318),
        child: CodeEditor(
          controller: controller.textController,
          scrollController: controller.editorScrollController,
          wordWrap: false,
          autocompleteSymbols: true,
          chunkAnalyzer: NonCodeChunkAnalyzer(),
          autofocus: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          onChanged: (_) {
            controller.updateCode();
          },
          style: CodeEditorStyle(
            fontFamily: _codeFontFamily,
            fontFamilyFallback: _codeFontFallback,
            fontSize: codeFontSize,
            fontHeight: 1.45,
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
                fontFamily: _codeFontFamily,
                fontFamilyFallback: _codeFontFallback,
                fontSize: lineNumberFontSize,
                height: 1.45,
                color: const Color(0xff5c6370),
              ),
              focusedTextStyle: TextStyle(
                fontFamily: _codeFontFamily,
                fontFamilyFallback: _codeFontFallback,
                fontSize: lineNumberFontSize,
                height: 1.45,
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
