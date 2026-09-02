enum RunnerStatus {
  idle,
  creating,
  ready,
  syncing,
  starting,
  running,
  reloading,
  restarting,
  stopping,
  stopped,
  error,
}

extension RunnerStatusLabel on RunnerStatus {
  String get label => switch (this) {
        RunnerStatus.idle => 'Idle',
        RunnerStatus.creating => 'Creating',
        RunnerStatus.ready => 'Ready',
        RunnerStatus.syncing => 'Syncing',
        RunnerStatus.starting => 'Starting',
        RunnerStatus.running => 'Running',
        RunnerStatus.reloading => 'Hot Reload',
        RunnerStatus.restarting => 'Hot Restart',
        RunnerStatus.stopping => 'Stopping',
        RunnerStatus.stopped => 'Stopped',
        RunnerStatus.error => 'Error',
      };
}

class RunSession {
  const RunSession({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.lastActivityAt,
    this.projectType = 'flutter',
    this.previewUrl,
  });

  final String id;
  final String projectType;
  final RunnerStatus status;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final String? previewUrl;

  RunSession copyWith({
    RunnerStatus? status,
    DateTime? lastActivityAt,
    String? previewUrl,
  }) {
    return RunSession(
      id: id,
      projectType: projectType,
      status: status ?? this.status,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
