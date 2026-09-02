import 'dart:convert';
import 'dart:io';

abstract interface class WorkspaceAuthenticator {
  Future<String?> authenticate(HttpRequest request);
}

class StaticBearerWorkspaceAuthenticator implements WorkspaceAuthenticator {
  const StaticBearerWorkspaceAuthenticator(this.tokenToUserId);

  final Map<String, String> tokenToUserId;

  factory StaticBearerWorkspaceAuthenticator.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'WORKSPACE_AUTH_TOKENS must be a JSON object mapping token to user id.',
      );
    }

    final result = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String ||
          (entry.key as String).isEmpty ||
          entry.value is! String ||
          (entry.value as String).isEmpty) {
        throw const FormatException(
          'WORKSPACE_AUTH_TOKENS keys and values must be non-empty strings.',
        );
      }
      result[entry.key as String] = entry.value as String;
    }
    return StaticBearerWorkspaceAuthenticator(Map.unmodifiable(result));
  }

  @override
  Future<String?> authenticate(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return null;
    final token = header.substring('Bearer '.length).trim();
    if (token.isEmpty) return null;
    return tokenToUserId[token];
  }
}
