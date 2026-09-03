import 'dart:io';

import 'workspace_secret_store.dart';
import 'workspace_store.dart';

class WorkspaceGitRemoteCheckResult {
  const WorkspaceGitRemoteCheckResult({
    required this.repositoryUrl,
    required this.branch,
    required this.provider,
    required this.branchFound,
    this.remoteHead,
  });

  final String repositoryUrl;
  final String branch;
  final String provider;
  final bool branchFound;
  final String? remoteHead;

  Map<String, Object?> toJson() => <String, Object?>{
        'repositoryUrl': repositoryUrl,
        'branch': branch,
        'provider': provider,
        'reachable': true,
        'branchFound': branchFound,
        'remoteHead': remoteHead,
      };
}

class WorkspaceGitRemoteException implements Exception {
  const WorkspaceGitRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WorkspaceGitCommandResult {
  const WorkspaceGitCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class WorkspaceGitCommandExecutor {
  Future<WorkspaceGitCommandResult> lsRemote({
    required String repositoryUrl,
    required String branch,
    String? username,
    String? secret,
  });
}

class ProcessWorkspaceGitCommandExecutor implements WorkspaceGitCommandExecutor {
  const ProcessWorkspaceGitCommandExecutor({this.gitExecutable = 'git'});

  final String gitExecutable;

  @override
  Future<WorkspaceGitCommandResult> lsRemote({
    required String repositoryUrl,
    required String branch,
    String? username,
    String? secret,
  }) async {
    Directory? askPassDirectory;
    try {
      final environment = <String, String>{
        ...Platform.environment,
        'GIT_TERMINAL_PROMPT': '0',
      };

      if (secret != null) {
        askPassDirectory = await Directory.systemTemp.createTemp(
          'workspace-git-askpass-',
        );
        final askPass = await _createAskPass(askPassDirectory);
        environment
          ..['GIT_ASKPASS'] = askPass.path
          ..['WORKSPACE_GIT_USERNAME'] = username ?? 'oauth2'
          ..['WORKSPACE_GIT_SECRET'] = secret;
      }

      final process = await Process.run(
        gitExecutable,
        <String>[
          'ls-remote',
          '--heads',
          repositoryUrl,
          'refs/heads/$branch',
        ],
        environment: environment,
        includeParentEnvironment: false,
        stdoutEncoding: SystemEncoding(),
        stderrEncoding: SystemEncoding(),
      );
      return WorkspaceGitCommandResult(
        exitCode: process.exitCode,
        stdout: '${process.stdout}',
        stderr: _redact('${process.stderr}', secret),
      );
    } finally {
      if (askPassDirectory != null && await askPassDirectory.exists()) {
        await askPassDirectory.delete(recursive: true);
      }
    }
  }

  Future<File> _createAskPass(Directory directory) async {
    if (Platform.isWindows) {
      final file = File('${directory.path}${Platform.pathSeparator}askpass.cmd');
      await file.writeAsString(
        '@echo off\r\n'
        'echo %~1 | findstr /I "Username" >nul\r\n'
        'if %errorlevel%==0 (\r\n'
        '  echo %WORKSPACE_GIT_USERNAME%\r\n'
        ') else (\r\n'
        '  echo %WORKSPACE_GIT_SECRET%\r\n'
        ')\r\n',
        flush: true,
      );
      return file;
    }

    final file = File('${directory.path}${Platform.pathSeparator}askpass.sh');
    await file.writeAsString(
      '#!/bin/sh\n'
      'case "\$1" in\n'
      '  *Username*) printf "%s\\n" "\$WORKSPACE_GIT_USERNAME" ;;\n'
      '  *) printf "%s\\n" "\$WORKSPACE_GIT_SECRET" ;;\n'
      'esac\n',
      flush: true,
    );
    final chmod = await Process.run('chmod', <String>['700', file.path]);
    if (chmod.exitCode != 0) {
      throw StateError('Unable to secure temporary Git askpass helper.');
    }
    return file;
  }

  static String _redact(String source, String? secret) {
    if (secret == null || secret.isEmpty) return source;
    return source.replaceAll(secret, '[REDACTED]');
  }
}

class WorkspaceGitRemoteChecker {
  const WorkspaceGitRemoteChecker({
    required this.workspaceStore,
    required this.secretStore,
    required this.executor,
  });

  final FileWorkspaceStore workspaceStore;
  final FileWorkspaceSecretStore secretStore;
  final WorkspaceGitCommandExecutor executor;

  Future<WorkspaceGitRemoteCheckResult> check({
    required String userId,
    required String workspaceId,
    String? secretName,
    String? username,
  }) async {
    final document = await workspaceStore.loadWorkspace(userId, workspaceId);
    if (document == null) {
      throw WorkspaceDocumentNotFound(workspaceId);
    }
    final project = document['project'];
    if (project is! Map) {
      throw const FormatException('Stored Workspace project is invalid.');
    }
    final remote = project['gitRemote'];
    if (remote is! Map) {
      throw const FormatException('Workspace has no Git remote binding.');
    }

    final repositoryUrl = _validateRepositoryUrl(remote['repositoryUrl']);
    final branch = _validateBranch(remote['branch']);
    final provider = _readProvider(remote['provider']);

    String? secret;
    if (secretName != null && secretName.trim().isNotEmpty) {
      secret = await secretStore.resolveForTrustedExecution(
        userId: userId,
        workspaceId: workspaceId,
        name: secretName.trim(),
        context: 'git',
      );
    }

    final result = await executor.lsRemote(
      repositoryUrl: repositoryUrl,
      branch: branch,
      username: secret == null
          ? null
          : (username?.trim().isNotEmpty == true
              ? username!.trim()
              : _defaultUsername(provider)),
      secret: secret,
    );
    if (result.exitCode != 0) {
      final detail = result.stderr.trim();
      throw WorkspaceGitRemoteException(
        detail.isEmpty ? 'Git remote check failed.' : detail,
      );
    }

    final firstLine = result.stdout
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final remoteHead =
        firstLine.isEmpty ? null : firstLine.split(RegExp(r'\s+')).first;

    return WorkspaceGitRemoteCheckResult(
      repositoryUrl: repositoryUrl,
      branch: branch,
      provider: provider,
      branchFound: remoteHead != null,
      remoteHead: remoteHead,
    );
  }

  String _validateRepositoryUrl(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Git repository URL is required.');
    }
    final source = value.trim();
    final scp = RegExp(
      r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+:[^\s]+$',
    ).hasMatch(source);
    if (scp) return source;

    final uri = Uri.tryParse(source);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Git repository URL must include a host.');
    }
    if (!const <String>{'https', 'http', 'ssh'}.contains(uri.scheme)) {
      throw const FormatException('Unsupported Git repository URL scheme.');
    }
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Git credentials must not be embedded in repository URL.',
      );
    }
    return source;
  }

  String _validateBranch(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Git branch is required.');
    }
    final source = value.trim();
    if (!RegExp(r'^[A-Za-z0-9._/-]+$').hasMatch(source) ||
        source.contains('..') ||
        source.contains('//') ||
        source.contains('@{') ||
        source.startsWith('/') ||
        source.endsWith('/')) {
      throw const FormatException('Invalid Git branch name.');
    }
    return source;
  }

  String _readProvider(Object? value) {
    if (value is! String || value.isEmpty) return 'generic';
    return switch (value) {
      'github' || 'gitlab' || 'bitbucket' || 'generic' => value,
      _ => 'generic',
    };
  }

  String _defaultUsername(String provider) => switch (provider) {
        'github' => 'x-access-token',
        'gitlab' => 'oauth2',
        'bitbucket' => 'x-token-auth',
        _ => 'oauth2',
      };
}
