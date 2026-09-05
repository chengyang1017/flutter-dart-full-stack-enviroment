# Flutter Developer Environment & Practice Runner

[English](README.md) | [简体中文](README.zh-CN.md)

A Flutter-based learning and experimentation environment for **reading code, practicing real application flows, rendering restricted Flutter UI syntax, importing/exporting workspaces, and running Flutter projects through a local or Docker-backed runner**.

This project started as a UI playground, but has grown into a broader developer-learning environment. Instead of only showing isolated widget examples, it is designed around understanding how real Flutter features are connected across models, services, repositories, state, UI, and application entry points.

---

## 🚀 Quick Start (Docker Compose)

```bash
# Clone the project
git clone https://github.com/chengyang1017/flutter-dart-fullstack-enviroment.git
cd flutter-dart-fullstack-enviroment

# Start all services
docker-compose up -d

# Open in browser
# → http://localhost:8080
```

✨ **That's it!** No configuration needed. The full Flutter environment is running.

📚 [See Full Deployment Guide](DEPLOYMENT.md) for advanced setup, production deployment, and troubleshooting.

---

## Screenshots

> Screenshot placeholders are intentionally kept here. Add the images under `docs/screenshots/` when they are ready.

### Main Learning Environment

📸 **Screenshot placeholder:** `docs/screenshots/home.png`

### Code Reader / Lesson View

📸 **Screenshot placeholder:** `docs/screenshots/code-reader.png`

### Flutter UI Playground

📸 **Screenshot placeholder:** `docs/screenshots/ui-playground.png`

### Shopping Cart Lesson

📸 **Screenshot placeholder:** `docs/screenshots/shopping-cart-lesson.png`

### Workspace / Project Import

📸 **Screenshot placeholder:** `docs/screenshots/workspace.png`

### Real Flutter Runner

📸 **Screenshot placeholder:** `docs/screenshots/runner.png`

### Mobile / Tablet Layout

📸 **Screenshot placeholder:** `docs/screenshots/mobile-layout.png`

---

## What This Project Explores

### 1. Real Feature-Based Learning

The lesson system is designed to explain complete application flows rather than disconnected code snippets.

For example, the shopping-cart lesson is split into a sequence that moves through the actual layers of a Flutter commerce feature:

```text
Product
  ↓
CartItem
  ↓
Cart Service
  ↓
Cart Repository
  ↓
State Management
  ↓
Cart UI
  ↓
Product Integration
  ↓
Checkout Integration
```

The current shopping-cart lesson contains **16 steps**, covering the path from product and cart models through services, repositories, state, UI, global injection, order conversion, and checkout.

This makes the project useful for studying questions such as:

- Where does data originate?
- Which layer changes the state?
- Which widget is only displaying derived state?
- How does one feature connect to another?
- Where should business logic live?

---

## 2. Restricted Flutter UI Playground

The project includes a safe Flutter-style UI playground that does not simply execute arbitrary Dart source directly inside the application.

The playground is separated into components such as:

```text
Source text
   ↓
Tokenizer
   ↓
Flutter UI Parser
   ↓
UI model / nodes
   ↓
Widget Registry
   ↓
Widget Renderer
   ↓
Flutter preview
```

Current parser components include:

```text
lib/features/playground/parser/
├── tokenizer.dart
├── parser_cursor.dart
└── flutter_ui_parser.dart
```

Rendering is handled separately through:

```text
lib/features/playground/renderer/
├── builders/
├── widget_registry.dart
└── widget_renderer.dart
```

This keeps parsing and rendering responsibilities separate and makes the supported syntax explicit instead of treating the playground as an unrestricted code executor.

---

## 3. Lessons and Source-Code Reading

Learning material is stored as project assets and can be connected to real source files and reference answers.

Current lesson assets include areas such as:

- Post creation
- Advanced image handling
- Shopping product flow
- Shopping cart flow

For the shopping-cart material, a helper PowerShell script can copy the original implementation files into the lesson assets and compare SHA-256 values to verify that the reference answers still match the source project.

That workflow helps keep teaching material connected to real implementation code instead of manually maintained examples that can silently drift out of date.

---

## 4. Workspace Import / Export

The application contains dedicated feature modules for project import, workspace handling, and export:

```text
lib/features/
├── export/
├── project_import/
└── workspace/
```

The goal is to make learning material portable and allow a practice workspace to be treated as a structured project rather than a single disposable text editor buffer.

---

## 5. Real Flutter Practice Runner

The repository includes a separate Dart server under:

```text
flutter-runner-server/
```

It can execute practice projects using two backends:

### Local execution

Runs Flutter directly on the runner host. This is useful for trusted local development.

### Docker execution

Creates an isolated Docker container for each practice session. This is the safer direction before allowing untrusted practice code to execute remotely.

A runner session can:

1. Create a temporary Flutter web project
2. Overlay portable workspace files
3. Run `flutter pub get`
4. Start `flutter run -d web-server`
5. Stream real stdout/stderr logs
6. Trigger hot reload
7. Trigger hot restart
8. Stop the running process
9. Dispose the temporary workspace and runtime

The client-facing API remains the same regardless of whether execution is local or Docker-backed.

---

## Runner Architecture

```text
Flutter Learning App
        │
        │ HTTP
        ▼
FlutterRunnerClient
        │
        ▼
Dart Runner API
        │
        ├──────────────┐
        │              │
        ▼              ▼
 Local Flutter      Docker Sandbox
 Runtime            Per Session
        │              │
        └──────┬───────┘
               ▼
        Flutter Web Preview
        + stdout / stderr
        + hot reload
        + hot restart
```

The runner API currently exposes session-oriented endpoints for creating sessions, uploading workspaces, starting runs, hot reloading, hot restarting, stopping, polling status/logs, and deleting sessions.

---

## Docker Sandbox Direction

The Docker runner applies boundaries such as:

- One container per practice session
- Non-root runtime user
- Memory limit
- CPU limit
- PID limit
- Reduced Linux capabilities
- `no-new-privileges`
- Default seccomp profile
- Preview ports bound to loopback by default
- No Docker socket mounted into the practice container
- Session cleanup after disposal / expiry

This does not make arbitrary code execution automatically production-safe, but it demonstrates the architectural direction required to separate practice code from the runner host.

---

## Project Structure

```text
.
├── lib/
│   ├── app/
│   ├── core/
│   ├── features/
│   │   ├── export/
│   │   ├── home/
│   │   ├── lessons/
│   │   ├── playground/
│   │   ├── project_import/
│   │   ├── runner/
│   │   └── workspace/
│   ├── shared/
│   └── main.dart
│
├── assets/
│   └── lessons/
│
├── flutter-runner-server/
│   ├── bin/
│   ├── docker/
│   ├── lib/
│   └── test/
│
├── SHOPPING_CART_LESSON_README.md
├── copy_shopping_cart_answers.ps1
├── shopping_cart_lesson_snippet.dart
└── pubspec.yaml
```

The Flutter client itself is organized by feature, while the runner remains a separate Dart service.

---

## Tech Stack

### Flutter Application

- Flutter
- Dart
- Hive / Hive Flutter
- Dart Analyzer
- `re_editor`
- `re_highlight`
- HTTP
- Archive utilities

### Playground

- Custom tokenizer
- Custom Flutter UI parser
- Widget registry
- Widget renderer
- Syntax highlighting

### Runner

- Dart server
- Flutter SDK
- HTTP session API
- Local process execution
- Docker-based isolated execution
- Flutter Web preview

---

## Persistent Learning State

The project uses Hive for local persistence, allowing learning progress and application state to survive restarts instead of resetting every time the tool is opened.

This matters because the environment is intended for longer learning flows rather than one-off widget demos.

---

## Example Learning Flow

```text
Open lesson
    ↓
Read the current responsibility
    ↓
Inspect related source code
    ↓
Understand its inputs / outputs
    ↓
Move to the next layer
    ↓
Edit or experiment in workspace
    ↓
Run Flutter project
    ↓
Observe real result and logs
```

The goal is to move from memorizing isolated code toward understanding **architecture, data flow, module responsibilities, and debugging paths**.

---

## Getting Started

### Option 1: Docker Compose (Recommended - Easiest)

```bash
# Clone and start
git clone https://github.com/chengyang1017/flutter-dart-fullstack-enviroment.git
cd flutter-dart-fullstack-enviroment
docker-compose up -d

# Open browser → http://localhost:8080
```

### Option 2: Local Flutter Development

```bash
git clone https://github.com/chengyang1017/flutter-dart-fullstack-enviroment.git
cd flutter-dart-fullstack-enviroment
flutter pub get
flutter run

# Or with web target
flutter run -d chrome --dart-define=RUNNER_API_URL=http://127.0.0.1:8787
```

### Option 3: Manual Runner Setup

Start the practice runner:

```bash
cd flutter-runner-server
dart pub get
dart run bin/server.dart
```

Then in another terminal, start the Flutter app:

```bash
flutter pub get
flutter run -d chrome --dart-define=RUNNER_API_URL=http://127.0.0.1:8787
```

### Project Analysis

```bash
flutter analyze
```

### Run Tests

```bash
flutter test
```

---

## Deployment & Advanced Setup

For production deployment, Docker configuration, environment setup, troubleshooting, and more:

📖 **[See Complete Deployment Guide →](DEPLOYMENT.md)**

Includes:
- Docker Compose setup (recommended)
- Single container deployment
- Nginx reverse proxy configuration
- Production best practices
- Troubleshooting tips

---

## Docker Quick Reference

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose stop

# Remove services and containers
docker-compose down

# Diagnose issues
./diagnose.sh
```

---

## Why This Project Exists

Most programming tutorials explain code file by file or provide finished snippets to copy.

This project explores a different approach:

```text
Feature
  ↓
Architecture
  ↓
Data flow
  ↓
Real source files
  ↓
Practice
  ↓
Execution
  ↓
Understanding
```

The long-term idea is a developer environment where reading, practicing, tracing, and running Flutter code belong to the same workflow.

---

## Status

**Active development.**

Implemented areas currently include the lesson system, feature-based learning flows, restricted Flutter UI parsing/rendering, workspace-related modules, persistent local state, and a real Flutter runner with both local and Docker execution modes.

Current work focuses on improving the code-reading experience, responsive layouts, runner safety, and making the environment useful across desktop, tablet, and smaller screens.
