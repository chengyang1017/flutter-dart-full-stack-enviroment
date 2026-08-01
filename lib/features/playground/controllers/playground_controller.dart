import 'dart:async';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../models/ui_node.dart';
import '../parser/flutter_ui_parser.dart';

enum PreviewDevice {
  androidPhone,
  smallPhone,
  tablet,
  responsive,
}

class PlaygroundController extends ChangeNotifier {
  PlaygroundController() {
    textController = CodeLineEditingController.fromText(
      exampleCode,
      const CodeLineOptions(
        indentSize: 4,
      ),
    );

    runCode();
  }

  static const exampleCode = """Container(
    color: Colors.white,
    padding: EdgeInsets.all(24),
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
            Icon(
                Icons.language,
                size: 64,
                color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
                '万文社',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                ),
            ),
            SizedBox(height: 8),
            Text(
                'Glyphora',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
                onPressed: null,
                child: Text('开始探索'),
            ),
        ],
    ),
)""";

  late final CodeLineEditingController textController;

  final FlutterUiParser _parser = FlutterUiParser();

  Timer? _debounce;

  UiNode? root;
  String? error;
  List<String> warnings = [];

  bool isParsing = false;
  bool autoRun = false;
  bool darkPreview = false;

  PreviewDevice device = PreviewDevice.androidPhone;

  String get code => textController.text;

  void updateCode() {
    // 中文输入法仍在组字时，不触发解析。
    if (textController.isComposing) {
      return;
    }

    error = null;

    if (!autoRun) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      runCode,
    );
  }

  void runCode() {
    _debounce?.cancel();

    isParsing = true;
    error = null;
    warnings = [];

    notifyListeners();

    final currentCode = code.trim();

    if (currentCode.isEmpty) {
      root = null;
      isParsing = false;
      notifyListeners();
      return;
    }

    try {
      root = _parser.parse(code);
    } catch (exception) {
      root = null;
      error = exception.toString();
    }

    isParsing = false;
    notifyListeners();
  }

  void clearCode() {
    _debounce?.cancel();

    textController.text = '';

    root = null;
    error = null;
    warnings = [];

    notifyListeners();
  }

  void resetExample() {
    _debounce?.cancel();

    textController.text = exampleCode;
    runCode();
  }

  void toggleAutoRun() {
    autoRun = !autoRun;

    notifyListeners();

    if (autoRun && !textController.isComposing) {
      runCode();
    }
  }

  void changeDevice(PreviewDevice value) {
    if (device == value) {
      return;
    }

    device = value;
    notifyListeners();
  }

  void togglePreviewTheme() {
    darkPreview = !darkPreview;
    notifyListeners();
  }

  void addWarning(String value) {
    if (warnings.contains(value)) {
      return;
    }

    warnings.add(value);
  }

  void clearWarnings() {
    if (warnings.isEmpty) {
      return;
    }

    warnings = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.dispose();

    super.dispose();
  }
}
