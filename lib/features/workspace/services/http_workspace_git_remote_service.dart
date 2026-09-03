import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/workspace_git_pull.dart';
import '../models/workspace_git_remote_check.dart';
import 'workspace_git_remote_service.dart';

class HttpWorkspaceGitRemoteService implements WorkspaceGitRemoteService {
  HttpWorkspaceGitRemoteService({
    required this.baseUri,
    required this.accessToken,
    required http.Client client,
  }) : _client = client;

  final Uri baseUri;
  final String accessToken;
  final http.Client _client;

  @override
  Future<WorkspaceGitRemoteCheckResult> checkRemote({
    required String workspaceId,
    String? secretName,
    String? username,
  }) async {
    final body = await _postGitAction(
      workspaceId: workspaceId,
      action: 'check',
      secretName: secretName,
      username: username,
      fallbackError: 'Git remote check failed.',
    );
    return WorkspaceGitRemoteCheckResult.fromJson(body);
  }

  @override
  Future<WorkspaceGitPullResult> pullRemote({
    required String workspaceId,
    String? secretName,
    String? username,
  }) async {
    final body = await _postGitAction(
      workspaceId: workspaceId,
      action: 'pull',
      secretName: secretName,
      username: username,
      fallbackError: 'Git pull failed.',
    );
    return WorkspaceGitPullResult.fromJson(body);
  }

  Future<Map<String, dynamic>> _postGitAction({
    required String workspaceId,
    required String action,
    required String fallbackError,
    String? secretName,
    String? username,
  }) async {
    final response = await _client.post(
      _uri(<String>['workspaces', workspaceId, 'git', action]),
      headers: <String, String>{
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        if (secretName?.trim().isNotEmpty == true)
          'secretName': secretName!.trim(),
        if (username?.trim().isNotEmpty == true) 'username': username!.trim(),
      }),
    );

    final body = _decodeObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      throw WorkspaceGitRemoteRequestException(
        statusCode: response.statusCode,
        message: error is String && error.isNotEmpty ? error : fallbackError,
      );
    }
    return body;
  }

  Uri _uri(List<String> segments) {
    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);
    return baseUri.replace(
      pathSegments: <String>[...baseSegments, ...segments],
      queryParameters: null,
      fragment: null,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Git remote response must be a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

class WorkspaceGitRemoteRequestException implements Exception {
  const WorkspaceGitRemoteRequestException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() =>
      'WorkspaceGitRemoteRequestException(statusCode: $statusCode, message: $message)';
}
