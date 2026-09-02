import 'dart:async';
import 'dart:io';

import 'package:workspace_storage_server/workspace_storage_server.dart';

Future<void> main() async {
  final environment = Platform.environment;
  final port = int.tryParse(environment['PORT'] ?? '') ?? 8090;
  final host = environment['HOST'] ?? '0.0.0.0';
  final storageRoot = environment['WORKSPACE_STORAGE_ROOT'] ?? '.workspace-storage';
  final temporaryTtlHours =
      int.tryParse(environment['TEMPORARY_WORKSPACE_TTL_HOURS'] ?? '') ?? 168;
  if (temporaryTtlHours <= 0) {
    stderr.writeln('TEMPORARY_WORKSPACE_TTL_HOURS must be greater than zero.');
    exitCode = 64;
    return;
  }

  final authTokens = environment['WORKSPACE_AUTH_TOKENS'];
  if (authTokens == null || authTokens.trim().isEmpty) {
    stderr.writeln(
      'WORKSPACE_AUTH_TOKENS is required. Example: '
      '''{"dev-token":"user-1"}''',
    );
    exitCode = 64;
    return;
  }

  final authenticator = StaticBearerWorkspaceAuthenticator.fromJson(authTokens);
  final handler = WorkspaceStorageHttpServer(
    store: FileWorkspaceStore(
      Directory(storageRoot),
      temporaryWorkspaceTtl: Duration(hours: temporaryTtlHours),
    ),
    authenticator: authenticator,
    allowedOrigin: environment['ALLOWED_ORIGIN'] ?? '*',
  );

  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    'Workspace storage listening on http://${server.address.address}:${server.port}',
  );
  stdout.writeln('Storage root: ${Directory(storageRoot).absolute.path}');
  stdout.writeln('Temporary Workspace TTL: $temporaryTtlHours hours');

  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('Received $signal; shutting down Workspace storage.');
    await server.close(force: true);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  if (!Platform.isWindows) {
    subscriptions.add(ProcessSignal.sigterm.watch().listen(shutdown));
  }
  subscriptions.add(ProcessSignal.sigint.watch().listen(shutdown));

  await for (final request in server) {
    unawaited(handler.handle(request));
  }
}
