import 'run_session.dart';

enum RunnerEventType {
  status,
  log,
}

class RunnerEvent {
  const RunnerEvent.status(this.status)
      : type = RunnerEventType.status,
        message = null;

  const RunnerEvent.log(this.message)
      : type = RunnerEventType.log,
        status = null;

  final RunnerEventType type;
  final RunnerStatus? status;
  final String? message;
}
