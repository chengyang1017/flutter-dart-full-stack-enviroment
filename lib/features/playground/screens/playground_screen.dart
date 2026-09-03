import 'dart:async';

import 'package:flutter/material.dart';

import '../../export/services/workspace_import_picker.dart';
import '../../project_import/services/flutter_project_zip_import_service.dart';
import '../../runner/controllers/flutter_runner_controller.dart';
import '../../runner/models/run_session.dart';
import '../../runner/models/runner_preview_target.dart';
import '../../runner/services/http_flutter_runner_client.dart';
import '../../runner/services/mock_flutter_runner_client.dart';
import '../../runner/services/runner_preview_tab.dart';
import '../../runner/widgets/runner_target_dialog.dart';
import '../../workspace/services/hive_workspace_persistence.dart';
import '../../workspace/services/keyed_workspace_snapshot_store.dart';
import '../../workspace/services/workspace_git_connection_runtime.dart';
import '../../workspace/services/workspace_persistence.dart';
import '../../workspace/services/workspace_project_library.dart';
import '../../workspace/services/workspace_snapshot_store.dart';
import '../../workspace/widgets/workspace_git_connection_dialog.dart';
import '../../workspace/widgets/workspace_git_remote_dialog.dart';
import '../../workspace/widgets/workspace_project_bar.dart';
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
  static const _runnerApiUrl = String.fromEnvironment('RUNNER_API_URL');

  late PlaygroundController controller;
  late FlutterRunnerController runner;

  WorkspacePersistence? _workspacePersistence;
  WorkspaceProjectLibrary? _projectLibrary;
  KeyedWorkspaceSnapshotStore? _activeProjectStore;
  WorkspaceGitConnectionRuntime? _gitConnectionRuntime;
  RunnerPreviewTabHandle? _pendingWebPreviewTab;

  @override
  void initState() {
    super.initState();
    _initializeProjectLibrary();
    _gitConnectionRuntime = WorkspaceGitConnectionRuntime.tryFromEnvironment();
    _createControllers();
  }

  void _initializeProjectLibrary() {
    final persistence = HiveWorkspacePersistence.tryFromOpenBoxes();
    if (persistence == null) return;

    _workspacePersistence = persistence;
    _projectLibrary = WorkspaceProjectLibrary.fromPersistence(persistence);
  }

  void _createControllers() {
    final project = _projectLibrary?.activeProject;
    final snapshotStore = _workspacePersistence?.snapshotStore;

    WorkspaceSnapshotStore? workspaceStore = snapshotStore;
    if (project != null && snapshotStore != null) {
      final projectStore = KeyedWorkspaceSnapshotStore(
        delegate: snapshotStore,
        storageKey: project.storageKey,
      );
      _activeProjectStore = projectStore;
      workspaceStore = projectStore;
    } else {
      _activeProjectStore = null;
    }

    controller = PlaygroundController(workspaceStore: workspaceStore)
      ..addListener(_refresh);
    runner = FlutterRunnerController(
      workspace: controller.workspace,
      client: _runnerApiUrl.isEmpty
          ? MockFlutterRunnerClient()
          : HttpFlutterRunnerClient(baseUrl: _runnerApiUrl),
    )..addListener(_refresh);
  }

  void _disposeControllers() {
    _closePendingWebPreviewTab();
    runner.removeListener(_refresh);
    runner.dispose();
    controller.removeListener(_refresh);
    controller.dispose();
    _activeProjectStore = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    _gitConnectionRuntime?.close();
    super.dispose();
  }

  void _refresh() {
    final pendingTab = _pendingWebPreviewTab;
    if (pendingTab != null) {
      final previewUrl = runner.previewUrl;
      if (runner.canHotReload && previewUrl != null) {
        pendingTab.navigate(previewUrl);
        _pendingWebPreviewTab = null;
      } else if (runner.status == RunnerStatus.error ||
          runner.status == RunnerStatus.stopped) {
        pendingTab.close();
        _pendingWebPreviewTab = null;
      }
    }

    if (mounted) setState(() {});
  }

  void _closePendingWebPreviewTab() {
    _pendingWebPreviewTab?.close();
    _pendingWebPreviewTab = null;
  }

  void _showRunTargetDialog(
    BuildContext dialogContext, {
    TabController? compactTabs,
  }) {
    if (!runner.canRun) return;

    showDialog<void>(
      context: dialogContext,
      builder: (_) => RunnerTargetDialog(
        onSelected: (target) {
          unawaited(
            _runTarget(
              target,
              compactTabs: compactTabs,
            ),
          );
        },
      ),
    );
  }

  Future<void> _runTarget(
    RunnerPreviewTarget target, {
    TabController? compactTabs,
  }) async {
    if (!runner.canRun) return;

    if (target.opensExternalTab && !runner.isMock) {
      _closePendingWebPreviewTab();
      final tab = openRunnerPreviewTab();
      if (tab.opened) {
        _pendingWebPreviewTab = tab;
      } else {
        scheduleMicrotask(() {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('浏览器阻止了网页预览标签页。请允许本站打开弹窗后重新运行。'),
            ),
          );
        });
      }
    } else if (target.opensExternalTab && runner.isMock) {
      scheduleMicrotask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock Runner 没有真实网页 Preview URL。请连接真实 Runner 后使用网页运行。'),
          ),
        );
      });
    }

    runner.selectPreviewTarget(target);
    await runner.run();

    if (!mounted || target.opensExternalTab) return;
    compactTabs?.animateTo(1);
  }

  Future<void> _switchProject(String projectId) async {
    final library = _projectLibrary;
    if (library == null || projectId == library.activeProjectId) return;

    final previousId = library.activeProjectId;
    await controller.flushWorkspacePersistence();
    await library.touchProject(previousId);
    await library.selectProject(projectId);
    await library.touchProject(projectId);

    _disposeControllers();
    _createControllers();
    if (mounted) setState(() {});
  }

  Future<void> _createProject() async {
    final library = _projectLibrary;
    if (library == null) return;

    final name = await _askProjectName(
      title: '新建练习',
      initialValue: 'Flutter Practice ${library.projects.length + 1}',
    );
    if (name == null || !mounted) return;

    try {
      await controller.flushWorkspacePersistence();
      await library.touchProject(library.activeProjectId);
      await library.createPractice(name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建练习失败：$error')),
      );
      return;
    }

    _disposeControllers();
    _createControllers();
    if (mounted) setState(() {});
  }

  Future<void> _importExistingFlutterProject() async {
    final library = _projectLibrary;
    if (library == null || !supportsWorkspaceImportPicker) return;

    try {
      final bytes = await pickWorkspaceImport();
      if (bytes == null || !mounted) return;

      final bundle = const FlutterProjectZipImportService().parse(bytes);
      await controller.flushWorkspacePersistence();
      await library.touchProject(library.activeProjectId);
      await library.createImportedFlutter(
        name: bundle.projectName,
        snapshot: bundle.snapshot,
      );

      _disposeControllers();
      _createControllers();
      if (!mounted) return;
      setState(() {});

      final ignored = bundle.ignoredFileCount == 0
          ? ''
          : '，忽略 ${bundle.ignoredFileCount} 个生成/平台文件';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导入 ${bundle.projectName}：${bundle.importedFileCount} 个文本文件$ignored。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flutter ZIP 导入失败：$error')),
      );
    }
  }

  Future<void> _renameProject() async {
    final library = _projectLibrary;
    if (library == null) return;
    final project = library.activeProject;

    final name = await _askProjectName(
      title: '重命名练习',
      initialValue: project.name,
    );
    if (name == null || !mounted) return;

    try {
      await library.renameProject(project.id, name);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重命名失败：$error')),
      );
    }
  }

  Future<void> _keepProject() async {
    final library = _projectLibrary;
    if (library == null) return;
    final project = library.activeProject;

    try {
      await library.keepProject(project.id);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保留 ${project.name}，不会再作为临时练习处理。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保留 Workspace 失败：$error')),
      );
    }
  }

  Future<void> _openGitTools() async {
    final library = _projectLibrary;
    if (library == null) return;
    final project = library.activeProject;

    if (project.gitRemote == null) {
      await _configureGitRemote();
      return;
    }

    final runtime = _gitConnectionRuntime;
    if (runtime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Git 远端服务未连接。请配置 WORKSPACE_STORAGE_API_URL 和 WORKSPACE_ACCESS_TOKEN。',
          ),
        ),
      );
      return;
    }

    var editRemote = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => WorkspaceGitConnectionDialog(
        project: project,
        loadSecrets: () => runtime.coordinator.listGitSecrets(
          project: project,
          snapshot: controller.workspace.createSnapshot(),
        ),
        checkConnection: ({secretName, secretValue, username}) =>
            runtime.coordinator.check(
          project: project,
          snapshot: controller.workspace.createSnapshot(),
          secretName: secretName,
          secretValue: secretValue,
          username: username,
        ),
        onEditRemote: () {
          editRemote = true;
          Navigator.pop(dialogContext);
        },
      ),
    );

    if (editRemote && mounted) {
      await _configureGitRemote();
    }
  }

  Future<void> _configureGitRemote() async {
    final library = _projectLibrary;
    if (library == null) return;
    final project = library.activeProject;

    final result = await showDialog<WorkspaceGitRemoteDialogResult>(
      context: context,
      builder: (_) => WorkspaceGitRemoteDialog(
        initialRemote: project.gitRemote,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (result.unbind) {
        await library.unbindGitRemote(project.id);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已解绑 ${project.name} 的 Git 仓库。')),
        );
        return;
      }

      final remote = result.remote;
      if (remote == null) return;
      final existing = project.gitRemote;
      final sameRemote = existing != null &&
          existing.repositoryUrl == remote.repositoryUrl &&
          existing.remoteName == remote.remoteName &&
          existing.branch == remote.branch;
      final binding = sameRemote
          ? remote.copyWith(lastSyncedHead: existing.lastSyncedHead)
          : remote;

      await library.bindGitRemote(project.id, binding);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已绑定 ${binding.repositoryUrl} · ${binding.branch}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Git 仓库设置失败：$error')),
      );
    }
  }

  Future<void> _deleteProject() async {
    final library = _projectLibrary;
    if (library == null || library.projects.length <= 1) return;
    final project = library.activeProject;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${project.name}？'),
        content: const Text(
          '这会删除这个浏览器本地练习的 Workspace 快照。Runner 临时环境也会被销毁。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await controller.flushWorkspacePersistence();
    _activeProjectStore?.disableWrites();
    _disposeControllers();

    try {
      await library.deleteProject(project.id);
    } catch (error) {
      _createControllers();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
      return;
    }

    _createControllers();
    if (mounted) setState(() {});
  }

  Future<String?> _askProjectName({
    required String title,
    required String initialValue,
  }) async {
    final textController = TextEditingController(text: initialValue);
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialValue.length,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 80,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              textController.text.trim(),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Widget _buildToolbar({
    required bool compact,
    VoidCallback? onRun,
    VoidCallback? onQuickPreview,
  }) {
    final toolbar = PlaygroundToolbar(
      controller: controller,
      runner: runner,
      compact: compact,
      onRun: onRun,
      onQuickPreview: onQuickPreview,
    );

    final library = _projectLibrary;
    if (library == null) return toolbar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WorkspaceProjectBar(
          projects: library.projects,
          activeProject: library.activeProject,
          onSelect: (id) => unawaited(_switchProject(id)),
          onCreate: () => unawaited(_createProject()),
          onImport: supportsWorkspaceImportPicker
              ? () => unawaited(_importExistingFlutterProject())
              : null,
          onKeep: () => unawaited(_keepProject()),
          onGitRemote: () => unawaited(_openGitTools()),
          onRename: () => unawaited(_renameProject()),
          onDelete: () => unawaited(_deleteProject()),
        ),
        toolbar,
      ],
    );
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
                  length: 4,
                  child: Builder(
                    builder: (tabContext) {
                      final tabs = DefaultTabController.of(tabContext);
                      return CompactPlaygroundLayout(
                        controller: controller,
                        runner: runner,
                        toolbar: _buildToolbar(
                          compact: true,
                          onRun: () => _showRunTargetDialog(
                            tabContext,
                            compactTabs: tabs,
                          ),
                          onQuickPreview: () {
                            controller.runCode();
                            tabs.animateTo(1);
                          },
                        ),
                      );
                    },
                  ),
                );
              }
              return WidePlaygroundLayout(
                controller: controller,
                runner: runner,
                toolbar: _buildToolbar(
                  compact: false,
                  onRun: () => _showRunTargetDialog(context),
                ),
              );
            },
          ),
        ),
      );
}
