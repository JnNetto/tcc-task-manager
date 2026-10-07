import 'dart:async';

/// Liga [OfflineTaskRepository] ao [SyncService]
Future<void> Function()? _afterLocalMutation;

void bindOfflineMutationSync(Future<void> Function()? runSync) {
  _afterLocalMutation = runSync;
}

void unbindOfflineMutationSync() {
  _afterLocalMutation = null;
}

/// Chamado após criar / atualizar / apagar tarefa em modo offline-first
void scheduleOfflineSyncAfterMutation() {
  final f = _afterLocalMutation;
  if (f != null) unawaited(f());
}
