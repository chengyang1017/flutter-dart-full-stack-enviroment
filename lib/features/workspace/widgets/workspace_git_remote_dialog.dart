import 'package:flutter/material.dart';

import '../models/workspace_git_remote.dart';

class WorkspaceGitRemoteDialog extends StatefulWidget {
  const WorkspaceGitRemoteDialog({
    super.key,
    this.initialRemote,
  });

  final WorkspaceGitRemote? initialRemote;

  @override
  State<WorkspaceGitRemoteDialog> createState() =>
      _WorkspaceGitRemoteDialogState();
}

class _WorkspaceGitRemoteDialogState extends State<WorkspaceGitRemoteDialog> {
  late final TextEditingController _repositoryController;
  late final TextEditingController _remoteNameController;
  late final TextEditingController _branchController;
  late final TextEditingController _projectPathController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final remote = widget.initialRemote;
    _repositoryController = TextEditingController(
      text: remote?.repositoryUrl ?? '',
    );
    _remoteNameController = TextEditingController(
      text: remote?.remoteName ?? 'origin',
    );
    _branchController = TextEditingController(
      text: remote?.branch ?? 'main',
    );
    _projectPathController = TextEditingController(
      text: remote?.projectPath ?? '',
    );
  }

  @override
  void dispose() {
    _repositoryController.dispose();
    _remoteNameController.dispose();
    _branchController.dispose();
    _projectPathController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final remote = WorkspaceGitRemote(
        repositoryUrl: _repositoryController.text,
        remoteName: _remoteNameController.text,
        branch: _branchController.text,
        projectPath: _projectPathController.text,
      );
      Navigator.pop(context, WorkspaceGitRemoteDialogResult.bind(remote));
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingRemote = widget.initialRemote != null;

    return AlertDialog(
      title: Text(hasExistingRemote ? 'Git 仓库设置' : '绑定 Git 仓库'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这里只保存仓库地址、分支和可选的 Flutter 项目子目录。Token、密码和 SSH 私钥不会写进 Workspace 元数据。',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('workspace-git-repository-url'),
                controller: _repositoryController,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Repository URL',
                  hintText: 'https://github.com/owner/repository.git',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final remoteField = TextField(
                    key: const ValueKey('workspace-git-remote-name'),
                    controller: _remoteNameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Remote',
                      hintText: 'origin',
                      border: OutlineInputBorder(),
                    ),
                  );
                  final branchField = TextField(
                    key: const ValueKey('workspace-git-branch'),
                    controller: _branchController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      hintText: 'main',
                      border: OutlineInputBorder(),
                    ),
                  );
                  if (compact) {
                    return Column(
                      children: [
                        remoteField,
                        const SizedBox(height: 12),
                        branchField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: remoteField),
                      const SizedBox(width: 12),
                      Expanded(child: branchField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('workspace-git-project-path'),
                controller: _projectPathController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Flutter project path（可选）',
                  hintText: '例如 apps/mobile；仓库根目录则留空',
                  helperText: 'Monorepo 有多个 Flutter 项目时，填写要同步的项目目录。',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  key: const ValueKey('workspace-git-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasExistingRemote)
          TextButton(
            key: const ValueKey('workspace-git-unbind'),
            onPressed: () => Navigator.pop(
              context,
              const WorkspaceGitRemoteDialogResult.unbind(),
            ),
            child: const Text('解绑'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('workspace-git-save'),
          onPressed: _save,
          child: Text(hasExistingRemote ? '保存' : '绑定'),
        ),
      ],
    );
  }
}

class WorkspaceGitRemoteDialogResult {
  const WorkspaceGitRemoteDialogResult.bind(this.remote) : unbind = false;

  const WorkspaceGitRemoteDialogResult.unbind()
      : remote = null,
        unbind = true;

  final WorkspaceGitRemote? remote;
  final bool unbind;
}
