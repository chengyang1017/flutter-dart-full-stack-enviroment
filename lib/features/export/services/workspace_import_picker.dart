import 'dart:typed_data';

import 'workspace_import_picker_stub.dart'
    if (dart.library.html) 'workspace_import_picker_web.dart' as implementation;

bool get supportsWorkspaceImportPicker =>
    implementation.supportsWorkspaceImportPicker;

Future<Uint8List?> pickWorkspaceImport() =>
    implementation.pickWorkspaceImport();
