enum WorkspaceProjectKind {
  practice,
  importedFlutter,
}

class WorkspaceProject {
  const WorkspaceProject({
    required this.id,
    required this.name,
    required this.storageKey,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String storageKey;
  final WorkspaceProjectKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkspaceProject copyWith({
    String? name,
    DateTime? updatedAt,
  }) {
    return WorkspaceProject(
      id: id,
      name: name ?? this.name,
      storageKey: storageKey,
      kind: kind,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'storageKey': storageKey,
        'kind': kind.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory WorkspaceProject.fromJson(Map<dynamic, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final storageKey = json['storageKey'];
    if (id is! String || id.isEmpty ||
        name is! String || name.isEmpty ||
        storageKey is! String || storageKey.isEmpty) {
      throw const FormatException('Invalid workspace project metadata.');
    }

    final kindName = json['kind'];
    final kind = WorkspaceProjectKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => WorkspaceProjectKind.practice,
    );

    DateTime readDate(dynamic value) => value is String
        ? DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();

    return WorkspaceProject(
      id: id,
      name: name,
      storageKey: storageKey,
      kind: kind,
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }
}
