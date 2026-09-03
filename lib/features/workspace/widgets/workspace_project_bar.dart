import 'package:flutter/material.dart';

import '../models/workspace_git_remote.dart';
import '../models/workspace_project.dart';

class WorkspaceProjectBar extends StatelessWidget {
  const WorkspaceProjectBar({
    super.key,
    required this.projects,
    required this.activeProject,
    required this.onSelect,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    this.onImport,
    this.onKeep,
    this.onGitRemote,
  });

  final List<WorkspaceProject> projects;
  final WorkspaceProject activeProject;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onImport;
  final VoidCallback? onKeep;
  final VoidCallback? onGitRemote;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showStatus = constraints.maxWidth >= 700;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_copy_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('workspace-project-selector'),
                        value: activeProject.id,
                        isExpanded: true,
                        onChanged: (value) {
                          if (value != null && value != activeProject.id) {
                            onSelect(value);
                          }
                        },
                        items: projects
                            .map(
                              (project) => DropdownMenuItem<String>(
                                value: project.id,
                                child: Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('workspace-project-create'),
                    tooltip: '新建练习',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 19),
                  ),
                  IconButton(
                    key: const ValueKey('workspace-project-import'),
                    tooltip: '打开 Flutter 项目 ZIP',
                    visualDensity: VisualDensity.compact,
                    onPressed: onImport,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                  ),
                  if (activeProject.lifecycle == WorkspaceLifecycle.temporary)
                    IconButton(
                      key: const ValueKey('workspace-project-keep'),
                      tooltip: '保留当前临时练习',
                      visualDensity: VisualDensity.compact,
                      onPressed: onKeep,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    ),
                  IconButton(
                    key: const ValueKey('workspace-project-git'),
                    tooltip: activeProject.gitRemote == null
                        ? '绑定 Git 仓库'
                        : 'Git 仓库设置',
                    visualDensity: VisualDensity.compact,
                    onPressed: onGitRemote,
                    icon: Icon(
                      activeProject.gitRemote == null
                          ? Icons.link_outlined
                          : Icons.account_tree_outlined,
                      size: 18,
                    ),
                  ),
                  PopupMenuButton<_WorkspaceProjectAction>(
                    key: const ValueKey('workspace-project-more'),
                    tooltip: 'Workspace 更多操作',
                    icon: const Icon(Icons.more_vert, size: 19),
                    onSelected: (action) {
                      switch (action) {
                        case _WorkspaceProjectAction.rename:
                          onRename();
                        case _WorkspaceProjectAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _WorkspaceProjectAction.rename,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined, size: 18),
                          title: Text('重命名'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _WorkspaceProjectAction.delete,
                        enabled: projects.length > 1,
                        child: const ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline, size: 18),
                          title: Text('删除'),
                        ),
                      ),
                    ],
                  ),
                  if (showStatus) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusText(activeProject),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusText(WorkspaceProject project) {
    final localStatus = switch ((project.kind, project.lifecycle)) {
      (WorkspaceProjectKind.importedFlutter, _) =>
        '已导入 Flutter Workspace · 浏览器本地保存',
      (_, WorkspaceLifecycle.temporary) => '临时练习 · 浏览器自动保存',
      _ => '已保留 Workspace · 浏览器本地保存',
    };

    final remote = project.gitRemote;
    if (remote == null) return '$localStatus · 未绑定 Git';

    final provider = _providerLabel(remote.provider);
    final sync = remote.lastSyncedHead == null ? '待首次同步' : '已同步';
    return '$localStatus · $provider ${remote.branch} · $sync';
  }

  String _providerLabel(WorkspaceGitProvider provider) => switch (provider) {
        WorkspaceGitProvider.github => 'GitHub',
        WorkspaceGitProvider.gitlab => 'GitLab',
        WorkspaceGitProvider.bitbucket => 'Bitbucket',
        WorkspaceGitProvider.generic => 'Git',
      };
}

enum _WorkspaceProjectAction {
  rename,
  delete,
}
