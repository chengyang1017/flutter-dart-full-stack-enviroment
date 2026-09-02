import 'package:flutter/material.dart';

Widget buildRunnerPreviewHost(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        '真实 Flutter Preview 已启动：\n$url\n\n当前平台不能内嵌 Web iframe，请在浏览器打开这个地址。',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
