import 'dart:io';

class RunnerLogEntry {
  const RunnerLogEntry({
    required this.index,
    required this.message,
  });

  final int index;
  final String message;

  Map<String, Object?> toJson() => {
        'index': index,
        'message': message,
      };
}

class RunnerSession {
  RunnerSession({
    required this.id,
    required this.directory,
    required this.createdAt,
  }) : lastActivityAt = createdAt;

  final String id;
  final Directory directory;
  final DateTime createdAt;
  DateTime lastActivityAt;

  String projectType = 'flutter';
  String status = 'creating';
  String? previewUrl;
  String? backendUrl;
  Process? process;
  Process? backendProcess;

  // Runtime-specific state is intentionally not serialized to clients.
  // Local execution does not need these fields; the Docker backend uses them
  // for its container id/name and host ports mapped to the two dev servers.
  String? runtimeId;
  int? runtimePreviewPort;
  int? runtimeBackendPort;

  final List<RunnerLogEntry> logs = <RunnerLogEntry>[];
  final Set<String> managedFiles = <String>{};

  void setStatus(String value) {
    status = value;
    touch();
  }

  void touch() {
    lastActivityAt = DateTime.now().toUtc();
  }

  void addLog(String message) {
    final trimmed = message.trimRight();
    if (trimmed.isEmpty) return;
    logs.add(
      RunnerLogEntry(
        index: logs.length,
        message: trimmed,
      ),
    );
    touch();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'projectType': projectType,
        'status': status,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastActivityAt': lastActivityAt.toUtc().toIso8601String(),
        'previewUrl': previewUrl,
        'backendUrl': backendUrl,
      };
}
