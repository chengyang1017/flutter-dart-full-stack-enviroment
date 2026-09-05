import 'dart:async';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../workspace/controllers/workspace_controller.dart';
import '../../workspace/models/workspace_snapshot.dart';
import '../../workspace/services/workspace_autosave.dart';
import '../../workspace/services/workspace_snapshot_store.dart';
import '../models/ui_node.dart';
import '../parser/flutter_ui_parser.dart';

enum PreviewDevice {
  androidPhone,
  smallPhone,
  tablet,
  responsive,
}

class PlaygroundController extends ChangeNotifier {
  PlaygroundController({WorkspaceSnapshotStore? workspaceStore}) {
    workspace = WorkspaceController.flutterPlayground(
      mainDartContent: exampleCode,
    );

    if (workspaceStore != null) {
      _workspaceAutosave = WorkspaceAutosave(
        workspace: workspace,
        store: workspaceStore,
        storageKey: workspaceStorageKey,
      );
    }

    _loadedWorkspacePath = workspace.activePath;
    _loadedWorkspaceEntryId = workspace.activeEntry?.id ?? '';
    final restoredEditorState =
        workspace.editorStateForEntryId(_loadedWorkspaceEntryId);

    textController = CodeLineEditingController.fromText(
      workspace.activeEntry?.content ?? '',
      const CodeLineOptions(
        indentSize: 4,
      ),
    );
    _applySelection(restoredEditorState);

    editorScrollController = CodeScrollController(
      verticalScroller: ScrollController(
        initialScrollOffset: restoredEditorState?.verticalOffset ?? 0,
      ),
      horizontalScroller: ScrollController(
        initialScrollOffset: restoredEditorState?.horizontalOffset ?? 0,
      ),
    );

    textController.addListener(_handleEditorValueChanged);
    editorScrollController.verticalScroller.addListener(_handleEditorScroll);
    editorScrollController.horizontalScroller.addListener(_handleEditorScroll);
    workspace.addListener(_handleWorkspaceChanged);

    // Initialize undo/redo history anchor.
    _recordInitialText();

    runCode();
  }

  static const workspaceStorageKey = 'default-playground';
  static const _quickPreviewStart = '// QUICK_PREVIEW_START';
  static const _quickPreviewEnd = '// QUICK_PREVIEW_END';

  static const exampleCode = """import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: PracticeExample(),
        ),
      ),
    ),
  );
}

class PracticeExample extends StatelessWidget {
  const PracticeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return
// QUICK_PREVIEW_START
Container(
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
)
// QUICK_PREVIEW_END
    ;
  }
}
""";

  late final CodeLineEditingController textController;
  late final CodeScrollController editorScrollController;
  late final WorkspaceController workspace;

  final FlutterUiParser _parser = FlutterUiParser();

  WorkspaceAutosave? _workspaceAutosave;
  Timer? _debounce;
  String _loadedWorkspacePath = '';
  String _loadedWorkspaceEntryId = '';
  bool _syncingWorkspaceSelection = false;
  bool _restoringEditorUiState = false;
  bool _skipCaptureOnNextWorkspaceSync = false;

  UiNode? root;
  String? error;
  List<String> warnings = [];

  bool isParsing = false;
  bool autoRun = false;
  bool darkPreview = false;

  PreviewDevice device = PreviewDevice.androidPhone;

  String get code => textController.text;
  String get activeFilePath => workspace.activePath;
  bool get restoredBrowserWorkspace =>
      _workspaceAutosave?.restoredSnapshot ?? false;

  bool get canQuickPreview => activeFilePath.endsWith('.dart');

  void selectWorkspaceFile(String path) {
    _captureEditorUiState();
    workspace.openFile(path);
  }

  void closeWorkspaceFile(String path) {
    if (path == workspace.activePath) {
      _captureEditorUiState();
    }
    workspace.closeFile(path);
  }

  void resetWorkspace() {
    _skipCaptureOnNextWorkspaceSync = true;
    workspace.resetWorkspace();
    runCode();
  }

  Future<void> flushWorkspacePersistence() async {
    _captureEditorUiState();
    await _workspaceAutosave?.flush();
  }

  void updateCode() {
    if (textController.isComposing) {
      return;
    }

    final path = workspace.activePath;
    if (path.isNotEmpty) {
      workspace.updateFileContentFromEditor(path, textController.text);
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

  /// Insert a code snippet at the current editor cursor position.
  ///
  /// The editor uses a line-based selection model (CodeLineSelection). This
  /// helper inserts `snippet` into the active line at the current offset and
  /// restores the cursor after the inserted text.
  // Simple undo/redo history stacks. These keep full-text snapshots which is
  // sufficient for an editor with moderate file sizes in this environment.
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isPerformingUndoRedo = false;
  String _lastRecordedText = '';

  void _recordInitialText() {
    _lastRecordedText = textController.text;
  }

  void insertSnippet(String snippet) {
    final sel = textController.selection;

    final normalized = textController.text.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');

    if (!_isPerformingUndoRedo) {
      // record previous state for undo
      _undoStack.add(_lastRecordedText);
      _redoStack.clear();
    }

    if (sel == null) {
      // No selection info — append to end.
      textController.text = normalized + snippet;
      _lastRecordedText = textController.text;
      updateCode();
      return;
    }

    final lineIndex = sel.index.clamp(0, lines.length - 1);
    final line = lines[lineIndex];
    final offset = sel.offset.clamp(0, line.length);

    final before = line.substring(0, offset);
    final after = line.substring(offset);

    lines[lineIndex] = before + snippet + after;

    final newText = lines.join('\n');
    final newOffset = before.length + snippet.length;

    textController.text = newText;
    textController.selection = CodeLineSelection.collapsed(
      index: lineIndex,
      offset: newOffset,
    );

    _lastRecordedText = textController.text;
    updateCode();
  }

  /// Undo the last editor change.
  void undo() {
    if (_undoStack.isEmpty) return;

    _isPerformingUndoRedo = true;
    try {
      _redoStack.add(textController.text);
      final previous = _undoStack.removeLast();
      textController.text = previous;
      textController.selection = CodeLineSelection.collapsed(index: 0, offset: 0);
      _lastRecordedText = previous;
      updateCode();
    } finally {
      _isPerformingUndoRedo = false;
    }
  }

  /// Redo the last undone change.
  void redo() {
    if (_redoStack.isEmpty) return;

    _isPerformingUndoRedo = true;
    try {
      _undoStack.add(textController.text);
      final next = _redoStack.removeLast();
      textController.text = next;
      textController.selection = CodeLineSelection.collapsed(index: 0, offset: 0);
      _lastRecordedText = next;
      updateCode();
    } finally {
      _isPerformingUndoRedo = false;
    }
  }

  /// Minimal formatter: trims trailing whitespace and ensures single final newline.
  void formatCode() {
    final current = textController.text.replaceAll('\r\n', '\n');
    final lines = current.split('\n');
    final trimmed = lines.map((l) => l.replaceAll(RegExp(r'\s+\$'), '')).join('\n');
    final result = trimmed.endsWith('\n') ? trimmed : trimmed + '\n';

    if (!_isPerformingUndoRedo) {
      _undoStack.add(_lastRecordedText);
      _redoStack.clear();
    }

    textController.text = result;
    _lastRecordedText = result;
    updateCode();
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
      root = _parser.parse(_quickPreviewSource(code));
    } catch (exception) {
      root = null;
      error = exception.toString();
    }

    isParsing = false;
    notifyListeners();
  }

  String _quickPreviewSource(String source) {
    final start = source.indexOf(_quickPreviewStart);
    final end = source.indexOf(_quickPreviewEnd);
    if (start == -1 || end == -1 || end <= start) {
      return source;
    }

    return source.substring(
      start + _quickPreviewStart.length,
      end,
    ).trim();
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

  void _handleEditorValueChanged() {
    if (_restoringEditorUiState) return;
    _captureEditorUiState();
  }

  void _handleEditorScroll() {
    if (_restoringEditorUiState) return;
    _captureEditorUiState();
  }

  void _captureEditorUiState({String? entryId}) {
    if (_restoringEditorUiState) return;
    final id = entryId ?? _loadedWorkspaceEntryId;
    if (id.isEmpty || workspace.entryById(id)?.isFile != true) return;

    final previous = workspace.editorStateForEntryId(id);
    final selection = textController.selection;
    final verticalScroller = editorScrollController.verticalScroller;
    final horizontalScroller = editorScrollController.horizontalScroller;

    workspace.updateEditorStateByEntryId(
      id,
      WorkspaceEditorState(
        baseIndex: selection.baseIndex,
        baseOffset: selection.baseOffset,
        extentIndex: selection.extentIndex,
        extentOffset: selection.extentOffset,
        verticalOffset: verticalScroller.hasClients
            ? verticalScroller.offset
            : previous?.verticalOffset ?? 0,
        horizontalOffset: horizontalScroller.hasClients
            ? horizontalScroller.offset
            : previous?.horizontalOffset ?? 0,
      ),
    );
    _workspaceAutosave?.requestSave();
  }

  void _handleWorkspaceChanged() {
    if (_syncingWorkspaceSelection) return;

    final path = workspace.activePath;
    final activeEntry = workspace.activeEntry;
    final workspaceContent = activeEntry?.content ?? '';
    final pathChanged = path != _loadedWorkspacePath;
    final contentChangedOutsideEditor = workspaceContent != textController.text;

    if (!pathChanged && !contentChangedOutsideEditor) {
      notifyListeners();
      return;
    }

    if (_skipCaptureOnNextWorkspaceSync) {
      _skipCaptureOnNextWorkspaceSync = false;
    } else {
      _captureEditorUiState(entryId: _loadedWorkspaceEntryId);
    }

    _syncingWorkspaceSelection = true;
    _restoringEditorUiState = true;
    _loadedWorkspacePath = path;
    _loadedWorkspaceEntryId = activeEntry?.id ?? '';
    textController.text = workspaceContent;
    final restoredState =
        workspace.editorStateForEntryId(_loadedWorkspaceEntryId);
    _applySelection(restoredState);
    root = null;
    error = null;
    warnings = [];
    _restoringEditorUiState = false;
    _syncingWorkspaceSelection = false;

    _restoreScrollAfterLayout(restoredState);
    notifyListeners();
  }

  void _applySelection(WorkspaceEditorState? state) {
    if (state == null || textController.text.isEmpty) {
      textController.selection = const CodeLineSelection.zero();
      return;
    }

    final lines = textController.text.split('\n');
    if (lines.isEmpty) {
      textController.selection = const CodeLineSelection.zero();
      return;
    }

    int clampIndex(int value) => value.clamp(0, lines.length - 1).toInt();
    int clampOffset(int index, int value) =>
        value.clamp(0, lines[index].length).toInt();

    final baseIndex = clampIndex(state.baseIndex);
    final extentIndex = clampIndex(state.extentIndex);
    textController.selection = CodeLineSelection(
      baseIndex: baseIndex,
      baseOffset: clampOffset(baseIndex, state.baseOffset),
      extentIndex: extentIndex,
      extentOffset: clampOffset(extentIndex, state.extentOffset),
    );
  }

  void _restoreScrollAfterLayout(WorkspaceEditorState? state) {
    final verticalTarget = state?.verticalOffset ?? 0;
    final horizontalTarget = state?.horizontalOffset ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_restoringEditorUiState) return;
      _jumpToStoredOffset(
        editorScrollController.verticalScroller,
        verticalTarget,
      );
      _jumpToStoredOffset(
        editorScrollController.horizontalScroller,
        horizontalTarget,
      );
    });
  }

  void _jumpToStoredOffset(ScrollController controller, double target) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final safeTarget = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(safeTarget.toDouble());
  }

  @override
  void dispose() {
    _captureEditorUiState();
    _debounce?.cancel();
    textController.removeListener(_handleEditorValueChanged);
    editorScrollController.verticalScroller.removeListener(_handleEditorScroll);
    editorScrollController.horizontalScroller.removeListener(_handleEditorScroll);
    _workspaceAutosave?.dispose();
    workspace.removeListener(_handleWorkspaceChanged);
    editorScrollController.dispose();
    workspace.dispose();
    textController.dispose();

    super.dispose();
  }
}
