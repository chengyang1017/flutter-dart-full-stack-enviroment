import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'features/workspace/services/hive_workspace_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('lesson_progress');
  await HiveWorkspacePersistence.openBoxes();
  runApp(const PlaygroundApp());
}
