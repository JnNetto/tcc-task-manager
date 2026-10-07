import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../../domain/models/sync_status.dart';
import '../offline/offline_task_repository.dart';
import '../offline/task_hive_model.dart';

/// Garante continuidade de dados entre modos online-first e offline-first.
///
/// O push não usa [NetworkSimulator] — é um flush de migração para o Firestore
/// canónico quando o participante volta a `online-first`.
class CrossArchitectureTaskBridge {
  CrossArchitectureTaskBridge._();

  static Future<void> flushPendingToFirestore({
    required Box<TaskHiveModel> tasksBox,
    required String participantId,
    FirebaseFirestore? firestore,
  }) async {
    final fs = firestore ?? FirebaseFirestore.instance;
    final col = fs
        .collection('participants')
        .doc(participantId)
        .collection('tasks');
    final local = OfflineTaskRepository(tasksBox);
    final pending = local.getPending();
    if (pending.isEmpty) return;

    for (final task in pending) {
      try {
        if (task.syncStatus == SyncStatus.deleted) {
          await col.doc(task.id).delete();
          await local.removeFromBox(task.id);
        } else {
          await col.doc(task.id).set(task.toFirestore());
          await local.markSynced(task.id);
        }
      } catch (_) {
        await local.markError(task.id);
      }
    }
  }
}
