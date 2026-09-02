import 'package:flutter/material.dart';

import '../controllers/flutter_runner_controller.dart';
import '../models/run_session.dart';

class RunnerConsolePanel extends StatelessWidget {
  const RunnerConsolePanel({
    super.key,
    required this.runner,
  });

  final FlutterRunnerController runner;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff0f1115),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: const BoxDecoration(
              color: Color(0xff181b20),
              border: Border(
                top: BorderSide(color: Color(0xff2c313c)),
                bottom: BorderSide(color: Color(0xff2c313c)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'CONSOLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: Color(0xffaab2bf),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: runner.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    runner.runnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff7f8794),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '清空控制台',
                  visualDensity: VisualDensity.compact,
                  onPressed: runner.logs.isEmpty ? null : runner.clearConsole,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: runner.logs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      runner.isMock
                          ? '当前使用 Mock Runner。启动 flutter-runner-server，并通过 --dart-define=RUNNER_API_URL=... 连接真实 Flutter SDK Runner。'
                          : '真实 Flutter SDK Runner 已连接，运行日志会显示在这里。',
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: Color(0xff7f8794),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: runner.logs.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: SelectableText(
                        runner.logs[index],
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: [
                            'Cascadia Mono',
                            'Courier New',
                          ],
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xffc9d1d9),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RunnerStatus status;

  @override
  Widget build(BuildContext context) {
    final isError = status == RunnerStatus.error;
    final isRunning = status == RunnerStatus.running;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isError
            ? const Color(0xff3d2024)
            : isRunning
                ? const Color(0xff173524)
                : const Color(0xff252a33),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isError
              ? const Color(0xffff9b9b)
              : isRunning
                  ? const Color(0xff8de5ad)
                  : const Color(0xffb8c0cc),
        ),
      ),
    );
  }
}
