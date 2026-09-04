# Flutter 开发者学习环境与练习运行器

[English](README.md) | [简体中文](README.zh-CN.md)

这是一个基于 Flutter 的开发者学习与实验环境，用于 **阅读代码、练习真实应用功能链、解析受限制的 Flutter UI 语法、导入/导出 Workspace，以及通过本地或 Docker Runner 真正运行 Flutter 项目**。

这个项目最初只是一个 Flutter UI Playground，但现在已经扩展成更完整的开发学习环境。它不只是展示零散 Widget 示例，而是希望帮助学习者理解真实 Flutter 功能如何跨越 Model、Service、Repository、状态管理、UI 和应用入口连接起来。

---

## 截图

> 下面暂时保留截图占位。准备好图片后放到 `docs/screenshots/` 即可。

### 主学习环境

📸 **截图占位：** `docs/screenshots/home.png`

### 代码阅读 / 教材页面

📸 **截图占位：** `docs/screenshots/code-reader.png`

### Flutter UI Playground

📸 **截图占位：** `docs/screenshots/ui-playground.png`

### 购物车教材

📸 **截图占位：** `docs/screenshots/shopping-cart-lesson.png`

### Workspace / 项目导入

📸 **截图占位：** `docs/screenshots/workspace.png`

### 真实 Flutter Runner

📸 **截图占位：** `docs/screenshots/runner.png`

### 手机 / 平板布局

📸 **截图占位：** `docs/screenshots/mobile-layout.png`

---

## 项目主要探索什么

### 1. 真实功能链学习

教材系统不是把代码拆成互不相关的小片段，而是按完整业务功能链来组织。

例如购物车教材会沿着真实 Flutter 商城功能依次理解：

```text
Product
  ↓
CartItem
  ↓
Cart Service
  ↓
Cart Repository
  ↓
状态管理
  ↓
Cart UI
  ↓
商品页接入
  ↓
Checkout 接入
```

当前购物车教材共有 **16 个步骤**，从 Product、CartItem、Service、Repository，一直到状态管理、UI、全局注入、OrderItem 转换和 Checkout。

它主要帮助理解这些问题：

- 数据最开始从哪里来？
- 哪一层真正修改状态？
- 哪个 Widget 只是显示派生状态？
- 一个功能是如何接到另一个功能上的？
- 业务逻辑应该放在哪一层？

---

## 2. 受限制的 Flutter UI Playground

项目内置一个安全方向的 Flutter 风格 UI Playground，并不是直接在应用内部随意执行任意 Dart 代码。

整体链路可以理解为：

```text
源码文字
   ↓
Tokenizer
   ↓
Flutter UI Parser
   ↓
UI Model / Nodes
   ↓
Widget Registry
   ↓
Widget Renderer
   ↓
Flutter Preview
```

目前 Parser 相关代码包括：

```text
lib/features/playground/parser/
├── tokenizer.dart
├── parser_cursor.dart
└── flutter_ui_parser.dart
```

渲染则独立放在：

```text
lib/features/playground/renderer/
├── builders/
├── widget_registry.dart
└── widget_renderer.dart
```

Parser 和 Renderer 分开，让支持的语法范围更加明确，也避免把 Playground 变成不受限制的代码执行器。

---

## 3. 教材与源码阅读

项目的学习材料会作为 Assets 保存，并可以和真实源码、标准答案连接。

目前教材内容包括：

- 发帖功能
- 高级图片处理
- 商城商品流程
- 购物车流程

购物车教材还提供 PowerShell 脚本，可以把原项目里的标准实现复制到教材 Assets，并逐个比较 SHA-256，确认教材答案和真实项目源码仍然一致。

这样可以减少“教材已经过时，但没人发现”的问题。

---

## 4. Workspace 导入 / 导出

项目已经拥有独立的 Workspace 相关 Feature：

```text
lib/features/
├── export/
├── project_import/
└── workspace/
```

目标是让练习内容不只是一个一次性的文本框，而是一个可以保存、导入、导出和继续使用的结构化项目 Workspace。

---

## 5. 真实 Flutter Practice Runner

仓库中还包含独立的 Dart Runner Server：

```text
flutter-runner-server/
```

Runner 支持两种执行方式。

### Local 模式

直接在 Runner 主机上执行 Flutter，适合可信任的本地开发环境。

### Docker 模式

每个练习 Session 建立独立 Docker Container，在未来需要运行不可信练习代码时，这是更合理的隔离方向。

一次 Runner Session 可以：

1. 创建临时 Flutter Web 项目
2. 覆盖用户 Workspace 文件
3. 执行 `flutter pub get`
4. 启动 `flutter run -d web-server`
5. 返回真实 stdout / stderr
6. 执行 Hot Reload
7. 执行 Hot Restart
8. 停止 Flutter Process
9. Session 结束后清理临时 Workspace 与运行环境

无论使用 Local 还是 Docker，Flutter 客户端面对的是同一套 Runner API。

---

## Runner 架构

```text
Flutter 学习 App
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
 Runtime            每个 Session 独立
        │              │
        └──────┬───────┘
               ▼
        Flutter Web Preview
        + stdout / stderr
        + Hot Reload
        + Hot Restart
```

Runner API 目前已经包含创建 Session、上传 Workspace、Run、Hot Reload、Hot Restart、Stop、读取状态/日志和删除 Session 等功能。

---

## Docker Sandbox 方向

Docker Runner 目前包含一些基本隔离边界，例如：

- 每个练习 Session 一个 Container
- 非 root 用户运行
- 内存限制
- CPU 限制
- PID 限制
- 减少 Linux capabilities
- `no-new-privileges`
- 默认 seccomp profile
- Preview Port 默认只绑定本机 loopback
- 不把 Docker socket 挂进练习 Container
- Session 结束 / 过期后删除 Container

这些措施并不代表“任意代码执行已经达到生产级绝对安全”，但它展示了把练习代码和 Runner Host 分离所需要的架构方向。

---

## 项目结构

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

Flutter 客户端以 Feature 方式组织，Runner 则保持为独立 Dart Service。

---

## 技术栈

### Flutter 应用

- Flutter
- Dart
- Hive / Hive Flutter
- Dart Analyzer
- `re_editor`
- `re_highlight`
- HTTP
- Archive utilities

### Playground

- 自定义 Tokenizer
- 自定义 Flutter UI Parser
- Widget Registry
- Widget Renderer
- Syntax Highlighting

### Runner

- Dart Server
- Flutter SDK
- HTTP Session API
- Local Process Execution
- Docker 隔离执行
- Flutter Web Preview

---

## 持久化学习状态

项目使用 Hive 保存本地状态，让学习进度和应用状态在关闭应用后仍然可以保留，而不是每次重新打开都从零开始。

这也说明它的目标不是一次性的 Widget Demo，而是可以持续使用的学习工具。

---

## 一个典型学习流程

```text
打开教材
    ↓
理解当前模块职责
    ↓
阅读相关源码
    ↓
理解输入 / 输出
    ↓
进入下一层
    ↓
在 Workspace 修改或实验
    ↓
运行真实 Flutter 项目
    ↓
观察结果与日志
```

项目希望帮助学习者从“背代码”逐渐转向理解 **架构、数据流、模块职责和调试路径**。

---

## 开始使用

### Flutter 应用

```bash
git clone https://github.com/chengyang1017/flutter-dart-fullstack-enviroment.git
cd flutter-dart-fullstack-enviroment
flutter pub get
flutter run
```

代码检查：

```bash
flutter analyze
```

测试：

```bash
flutter test
```

---

## 使用真实 Flutter Runner

进入 Runner 目录：

```bash
cd flutter-runner-server
dart pub get
dart run bin/server.dart
```

然后启动 Flutter Web Client，并指定 Runner：

```bash
flutter run -d chrome --dart-define=RUNNER_API_URL=http://127.0.0.1:8787
```

如果没有设置 `RUNNER_API_URL`，客户端可以使用 Mock Runner，方便单独开发 UI。

Docker Runner 详细说明见：

```text
flutter-runner-server/README.md
```

---

## 为什么做这个项目

很多编程教材都是按文件解释，或者直接给完成后的代码让人复制。

这个项目想尝试另一种学习方式：

```text
Feature
  ↓
Architecture
  ↓
Data Flow
  ↓
真实源码
  ↓
Practice
  ↓
Execution
  ↓
Understanding
```

长期目标是让 **读代码、练代码、追踪功能链和真正运行 Flutter 项目** 都发生在同一个开发学习环境里。

---

## 状态

**持续开发中。**

目前已经包含教材系统、完整功能链学习、受限制 Flutter UI Parser / Renderer、Workspace 相关模块、本地持久化，以及同时支持 Local 与 Docker 模式的真实 Flutter Runner。

接下来重点是继续改善代码阅读体验、响应式布局、Runner 安全性，以及让 Desktop、Tablet 和较小屏幕都能更好地使用这个环境。
