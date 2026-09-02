class WorkspaceIdentity {
  const WorkspaceIdentity({required this.userId});

  /// Stable account id resolved from the authenticated server session.
  ///
  /// This value identifies the current platform account. Workspace ownership
  /// must still be enforced by the server; clients must never be trusted to
  /// choose an arbitrary owner id for remote operations.
  final String userId;

  @override
  String toString() => 'WorkspaceIdentity(userId: $userId)';
}
