import 'package:hive/hive.dart';

import '../../domain/models/sync_status.dart';
import '../../domain/models/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../services/telemetry_service.dart';
import 'task_hive_model.dart';

class OfflineTaskRepository implements TaskRepository {
  final Box<TaskHiveModel> _box;

  OfflineTaskRepository(this._box);

  @override
  Future<void> createTask(Task task) async {
    // Fonte de verdade local: toda criacao no prototipo offline entra pendente
    // para garantir envio posterior ao Firestore pelo SyncService.
    final local = task.copyWith(
      syncStatus: SyncStatus.pending,
      pendingSince: task.pendingSince ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _box.put(local.id, TaskHiveModel.fromDomain(local));
    TelemetryService.instance.logOperationCompleted(
      'create',
      local.id,
      success: true,
      local: true,
    );
  }

  @override
  Stream<List<Task>> watchTasks() {
    List<Task> buildTasks() {
      final tasks = _box.values
          .where((m) => m.syncStatus != SyncStatus.deleted.index)
          .map((m) => m.toDomain())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      TelemetryService.instance.logEvent(
        'tasks_loaded_local',
        data: {
          'count': tasks.length,
          'pending':
              tasks.where((t) => t.syncStatus == SyncStatus.pending).length,
        },
      );
      return tasks;
    }

    return Stream<List<Task>>.multi((controller) {
      controller.add(buildTasks());
      final sub = _box.watch().listen((_) {
        controller.add(buildTasks());
      });
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    final updated = task.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      pendingSince: task.pendingSince ?? DateTime.now(),
    );
    await _box.put(task.id, TaskHiveModel.fromDomain(updated));
    TelemetryService.instance.logOperationCompleted(
      'update',
      task.id,
      success: true,
      local: true,
    );
  }

  @override
  Future<void> reorderTasks(List<Task> orderedTasks) async {
    // Reordenacao e apenas preferencia local de UI (TaskProvider).
    // Nao altera estado de sincronizacao nem dados persistidos da tarefa.
    return;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final model = _box.get(taskId);
    if (model != null) {
      model.syncStatus = SyncStatus.deleted.index;
      model.pendingSince = DateTime.now();
      await model.save();
    }
    TelemetryService.instance.logOperationCompleted(
      'delete',
      taskId,
      success: true,
      local: true,
    );
  }

  List<Task> getPending() => _box.values
      .where(
        (m) =>
            m.syncStatus == SyncStatus.pending.index ||
            m.syncStatus == SyncStatus.deleted.index,
      )
      .map((m) => m.toDomain())
      .toList();

  Task? getById(String id) {
    final model = _box.get(id);
    return model?.toDomain();
  }

  Future<void> createTaskFromRemote(Task task) async {
    final model = TaskHiveModel.fromDomain(
      task.copyWith(
        syncStatus: SyncStatus.synced,
        pendingSince: null,
      ),
    );
    await _box.put(task.id, model);
  }

  Future<void> updateTaskFromRemote(Task task) async {
    final model = TaskHiveModel.fromDomain(
      task.copyWith(
        syncStatus: SyncStatus.synced,
        pendingSince: null,
      ),
    );
    await _box.put(task.id, model);
  }

  Future<void> markSynced(String id) async {
    final m = _box.get(id);
    if (m != null) {
      m.syncStatus = SyncStatus.synced.index;
      m.pendingSince = null;
      await m.save();
    }
  }

  Future<void> markError(String id) async {
    final m = _box.get(id);
    if (m != null) {
      m.syncStatus = SyncStatus.error.index;
      await m.save();
    }
  }

  Future<void> removeFromBox(String id) async => _box.delete(id);

  @override
  Future<Task?> getTaskById(String taskId) async {
    final m = _box.get(taskId);
    return m?.toDomain();
  }
}
