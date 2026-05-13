import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../services/network_simulator.dart';
import '../../services/telemetry_service.dart';

class OnlineTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore;
  final String participantId;

  OnlineTaskRepository({
    required this.participantId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection('participants')
      .doc(participantId)
      .collection('tasks');

  @override
  Future<void> createTask(Task task) async {
    await NetworkSimulator.instance.intercept('create_task', () async {
      TelemetryService.instance.logOperationStarted('create', task.id);
      try {
        await _col.doc(task.id).set(task.toFirestore());
        TelemetryService.instance.logOperationCompleted(
          'create',
          task.id,
          success: true,
        );
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
          'create',
          task.id,
          success: false,
          error: e.code,
        );
        rethrow;
      }
    });
  }

  @override
  Stream<List<Task>> watchTasks() {
    if (!NetworkSimulator.instance.isConnected) {
      TelemetryService.instance.logOperationBlocked('watch_tasks');
      return Stream.error(
        OfflineException('Sem conexão. Conecte-se para ver suas tarefas.'),
      );
    }
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: false)
        .map((s) {
      TelemetryService.instance.logEvent(
        'tasks_fetched_server',
        data: {'count': s.docs.length},
      );
      return s.docs.map((d) => Task.fromFirestore(d)).toList();
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    await NetworkSimulator.instance.intercept('update_task', () async {
      TelemetryService.instance.logOperationStarted('update', task.id);
      try {
        await _col.doc(task.id).update(task.toFirestore());
        TelemetryService.instance.logOperationCompleted(
          'update',
          task.id,
          success: true,
        );
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
          'update',
          task.id,
          success: false,
          error: e.code,
        );
        rethrow;
      }
    });
  }

  @override
  Future<void> reorderTasks(List<Task> orderedTasks) async {
    // Reordenacao e apenas preferencia local de UI (TaskProvider).
    // Nao persiste no Firestore para nao misturar com a camada arquitetural.
    return;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await NetworkSimulator.instance.intercept('delete_task', () async {
      TelemetryService.instance.logOperationStarted('delete', taskId);
      try {
        await _col.doc(taskId).delete();
        TelemetryService.instance.logOperationCompleted(
          'delete',
          taskId,
          success: true,
        );
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
          'delete',
          taskId,
          success: false,
          error: e.code,
        );
        rethrow;
      }
    });
  }

  @override
  Future<Task?> getTaskById(String taskId) async {
    try {
      final doc = await _col.doc(taskId).get();
      if (!doc.exists) return null;
      return Task.fromFirestore(doc);
    } on FirebaseException {
      return null;
    }
  }
}
