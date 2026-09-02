import 'dart:async';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../workspace/controllers/workspace_controller.dart';
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
    workspace = WorkspaceController.flutterPlayground(
      mainDartContent: exampleCode,
    );
    _loadedWorkspacePath = workspace.activePath;

    textController = CodeLineEditingController.fromText(
      workspace.activeEntry?.content ?? '',
      const CodeLineOptions(
        indentSize: 4,
      ),
    );

    workspace.addListener(_handleWorkspaceChanged);
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
  late final WorkspaceController workspace;

  final FlutterUiParser _parser = FlutterUiParser();

  Timer? _debounce;
  String _loadedWorkspacePath = '';
  bool _syncingWorkspaceSelection = false;

  UiNode? root;
  String? error;
  List<String> warnings = [];

  bool isParsing = false;
  bool autoRun = false;
  bool darkPreview = false;

  PreviewDevice device = PreviewDevice.androidPhone;

  String get code => textController.text;
  String get activeFilePath => workspace.activePath;

  bool get canQuickPreview => activeFilePath.endsWith('.dart');

  void selectWorkspaceFile(String path) {
    workspace.openFile(path);
  }

  void closeWorkspaceFile(String path) {
    workspace.closeFile(path);
  }

  void resetWorkspace() {
    workspace.resetWorkspace();
    runCode();
  }

  void updateCode() {
    if (textController.isComposing) {
      return;
    }

    final path = workspace.activePath;
    if (path.isNotEmpty) {
      workspace.updateFileContent(path, textController.text);
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

    if (!canQuickPreview) {
      root = null;
      error = 'Quick Preview 只解析 Dart Widget 代码。当前文件：$activeFilePath';
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
    final path = workspace.activePath;
    if (path.isNotEmpty) {
      workspace.updateFileContent(path, '');
    }

    root = null;
    error = null;
    warnings = [];

    notifyListeners();
  }

  void resetExample() {
    _debounce?.cancel();

    workspace.openFile('lib/main.dart');
    workspace.updateFileContent('lib/main.dart', exampleCode);
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

  void _handleWorkspaceChanged() {
    if (_syncingWorkspaceSelection) return;

    final path = workspace.activePath;
    if (path != _loadedWorkspacePath) {
      _syncingWorkspaceSelection = true;
      _loadedWorkspacePath = path;
      textController.text = workspace.activeEntry?.content ?? '';
      root = null;
      error = null;
      warnings = [];
      _syncingWorkspaceSelection = false;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    workspace.removeListener(_handleWorkspaceChanged);
    workspace.dispose();
    textController.dispose();

    super.dispose();
  }
}
