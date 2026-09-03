import '../models/workspace_git_remote_check.dart';

abstract interface class WorkspaceGitRemoteService {
  Future<WorkspaceGitRemoteCheckResult> checkRemote({
    required String workspaceId,
    String? secretName,
    String? username,
  });
}
