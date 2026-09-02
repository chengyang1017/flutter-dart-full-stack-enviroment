# Flutter Practice Runner Server

This directory contains the first real Flutter SDK runner for `flutter_learining`.

It is intentionally a **local-development runner**, not the production sandbox yet.
The server launches real user Flutter code on the host machine, so do not expose it to untrusted users or the public internet. Container isolation comes in Phase 5.

## What it does

For each practice session the runner:

1. creates a temporary session directory;
2. runs `flutter create --no-pub --platforms=web` to materialize the generated Flutter web platform files;
3. overlays the user's portable Workspace files such as `lib/`, `assets/`, `test/`, `pubspec.yaml`, and `analysis_options.yaml`;
4. runs `flutter pub get`;
5. runs `flutter run -d web-server` on a temporary port;
6. exposes the real Flutter stdout/stderr logs through the Runner API;
7. sends `r`, `R`, and `q` to the live Flutter process for hot reload, hot restart, and stop;
8. removes the temporary project when the session is disposed or expires.

## Requirements

- Flutter SDK available on `PATH`, or set `FLUTTER_EXECUTABLE`.
- Dart is already included with Flutter.

## Start the runner

From this directory:

```bash
dart pub get
dart run bin/server.dart
```

Default API address:

```text
http://127.0.0.1:8787
```

Health check:

```text
GET http://127.0.0.1:8787/health
```

## Start the Flutter practice web app with the real runner

From the repository root:

```bash
flutter pub get
flutter run -d chrome --dart-define=RUNNER_API_URL=http://127.0.0.1:8787
```

When `RUNNER_API_URL` is present, the UI uses `HttpFlutterRunnerClient` and the button is shown as `Run`.
When it is absent, the app intentionally falls back to `MockFlutterRunnerClient` and shows `Run (Mock)`.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `RUNNER_HOST` | `127.0.0.1` | HTTP API bind host |
| `RUNNER_PORT` | `8787` | HTTP API port |
| `FLUTTER_EXECUTABLE` | `flutter` | Flutter executable/path |
| `RUNNER_WORKSPACE_ROOT` | OS temp directory | Session workspace parent |
| `RUNNER_ALLOWED_ORIGIN` | `*` | CORS origin for local development |
| `RUNNER_IDLE_MINUTES` | `20` | Dispose sessions without a client heartbeat |
| `RUNNER_PREVIEW_URL_TEMPLATE` | `http://localhost:{port}` | Browser-visible preview URL; `{port}` is replaced with the assigned Flutter web-server port |

For a runner hosted on another machine, `RUNNER_PREVIEW_URL_TEMPLATE` must point at a browser-reachable address. Production hosting will replace direct temporary ports with a reverse-proxy/session URL.

## API

```text
POST   /sessions
GET    /sessions/:id?afterLog=0
PUT    /sessions/:id/workspace
POST   /sessions/:id/run
POST   /sessions/:id/hot-reload
POST   /sessions/:id/hot-restart
POST   /sessions/:id/stop
DELETE /sessions/:id
```

The current client polls the session endpoint for status and new logs. A later phase can replace polling with WebSocket/SSE without changing the `FlutterRunnerClient` abstraction.

## Security boundary

Current Phase 4 deliberately binds to loopback by default, but that alone is not a production sandbox. Flutter/Dart code executed by this server has the permissions of the runner process.

Before public deployment, Phase 5 must place each session inside an isolated container with CPU, memory, filesystem, process, network, and lifetime limits.
