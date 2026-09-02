import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('lesson_progress');
  await Hive.openBox<dynamic>('workspace_snapshots');
  await Hive.openBox<dynamic>('workspace_library');
  runApp(const PlaygroundApp());
}
