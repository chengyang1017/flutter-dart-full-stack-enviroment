# Workspace Storage Server

This service is the durable Workspace storage boundary for the Dart-first cloud IDE. It is intentionally separate from `flutter-runner-server`: Runtime containers may be disposable, while Workspace source must survive browser closes, runner restarts, and machine changes.

## Local development

```bash
cd workspace-storage-server
dart pub get

export WORKSPACE_AUTH_TOKENS='{"dev-token":"user-1"}'
export WORKSPACE_STORAGE_ROOT='.workspace-storage'
dart run bin/server.dart
```

Windows PowerShell:

```powershell
$env:WORKSPACE_AUTH_TOKENS='{"dev-token":"user-1"}'
$env:WORKSPACE_STORAGE_ROOT='.workspace-storage'
dart run bin/server.dart
```

The token mapping is only a development authentication adapter. Production deployment should replace it with a real identity provider/session verifier while keeping the storage API user-scoped on the server.

## API

All `/workspaces` routes require `Authorization: Bearer <token>`.

- `GET /workspaces` — current user's Workspace catalog
- `GET /workspaces/:id` — load one Workspace document
- `POST /workspaces` — create a Workspace
- `PUT /workspaces/:id` — save with `expectedRevision`
- `DELETE /workspaces/:id` — delete with `expectedRevision`
- `GET /health` — liveness check

The client never supplies an `ownerId`. Ownership comes from the authenticated server session. Saves and deletes use opaque revisions for optimistic concurrency; stale writes return HTTP 409 with `code: revision_conflict`.

## Persistence

The first implementation writes per-user catalogs and Workspace documents under `WORKSPACE_STORAGE_ROOT`. In deployment that directory must be mounted on durable storage. The storage boundary is deliberately isolated so a later PostgreSQL/object-storage implementation can replace the filesystem store without changing the Flutter Workspace contract.
