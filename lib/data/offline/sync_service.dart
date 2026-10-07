import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/sync_status.dart';
import '../../domain/models/task.dart';
import '../../services/network_simulator.dart';
import '../../services/telemetry_service.dart';
import 'offline_mutation_sync_trigger.dart';
import 'offline_task_repository.dart';

/// Sincronização em background offline-first (cf. especificação técnica):
/// - **Push** (Hive → Firestore): respeita [NetworkSimulator.checkPushToRemoteAllowed].
/// - **Pull** (Firestore → Hive): **sempre** tentado; referência remota converge para o local.
/// - Conflitos com cópia local já sincronizada: LWW por `updatedAt` (remoto ≥ local).
class SyncService {
  SyncService({
    required OfflineTaskRepository localRepo,
    required this.participantId,
    FirebaseFirestore? firestore,
  }) : _local = localRepo,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final OfflineTaskRepository _local;
  final FirebaseFirestore _firestore;
  final String participantId;
  bool _isSyncing = false;
  Timer? _periodicTimer;
  bool _hasCompletedAnySyncCycle = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('participants').doc(participantId).collection('tasks');

  void start() {
    debugPrint('[SyncService] start() - participantId=$participantId');
    bindOfflineMutationSync(_syncIfNotBusy);
    unawaited(_syncIfNotBusy());
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _syncIfNotBusy(),
    );
  }

  Future<void> syncNow() => _syncIfNotBusy();

  Future<void> _syncIfNotBusy() async {
    if (_isSyncing) {
      debugPrint('[SyncService] skip: sync ja em execucao');
      return;
    }
    debugPrint('[SyncService] iniciando ciclo push+pull');
    await _doSync();
  }

  Future<void> _doSync() async {
    _isSyncing = true;
    try {
      final pending = _local.getPending();
      final pushAllowed =
          await NetworkSimulator.instance.checkPushToRemoteAllowed(
        'sync_service_push',
      );

      debugPrint(
        '[SyncService] pendentes=${pending.length} pushAllowed=$pushAllowed',
      );

      final isFirstCycle = !_hasCompletedAnySyncCycle;
      TelemetryService.instance.logSyncStarted(
        pendingCount: pending.length,
        isFirstSync: isFirstCycle,
      );

      int pushed = 0;
      int pulled = 0;
      int errors = 0;

      // PUSH (local → remoto) — só quando o simulador permite envio ao canónico.
      if (pushAllowed) {
        for (final task in pending) {
          try {
            if (task.syncStatus == SyncStatus.deleted) {
              debugPrint('[SyncService] delete remoto task=${task.id}');
              await _col.doc(task.id).delete();
              await _local.removeFromBox(task.id);
            } else {
              debugPrint('[SyncService] upsert remoto task=${task.id}');
              await _col.doc(task.id).set(task.toFirestore());
              await _local.markSynced(task.id);
            }
            pushed++;
            TelemetryService.instance.logSyncItem(
              task.id,
              direction: 'push',
              success: true,
              pendingDuration: task.pendingSince != null
                  ? DateTime.now().difference(task.pendingSince!)
                  : null,
            );
          } catch (e) {
            await _local.markError(task.id);
            errors++;
            debugPrint('[SyncService] erro task=${task.id} -> $e');
            TelemetryService.instance.logSyncItem(
              task.id,
              direction: 'push',
              success: false,
              error: e.toString(),
            );
          }
        }
      } else {
        debugPrint(
          '[SyncService] push ignorado (degradacao); pull segue para convergencia',
        );
      }

      // PULL (remoto → local) — sempre: lista completa do Firestore para espelhar o canónico.
      try {
        final snapshot = await _col.get();
        debugPrint('[SyncService] pull docs=${snapshot.docs.length}');

        for (final doc in snapshot.docs) {
          try {
            final remote = Task.fromFirestore(doc);
            final local = _local.getById(remote.id);

            if (local == null) {
              await _local.createTaskFromRemote(remote);
              pulled++;
              TelemetryService.instance.logSyncItem(
                remote.id,
                direction: 'pull',
                success: true,
              );
              continue;
            }

            final localHasUnsynced =
                local.syncStatus == SyncStatus.pending ||
                local.syncStatus == SyncStatus.deleted ||
                local.syncStatus == SyncStatus.error;

            // LWW por updatedAt quando o local já reflete o último push bem-sucedido.
            // Alterações pendentes locais não são sobrescritas até serem enviadas.
            final remoteWinsOrTie = !remote.updatedAt.isBefore(local.updatedAt);
            if (remoteWinsOrTie && !localHasUnsynced) {
              await _local.updateTaskFromRemote(remote);
              pulled++;
              TelemetryService.instance.logSyncItem(
                remote.id,
                direction: 'pull',
                success: true,
              );
            }
          } catch (e, st) {
            errors++;
            debugPrint(
              '[SyncService] pull skip doc=${doc.id} erro=$e\n$st',
            );
            TelemetryService.instance.logSyncItem(
              doc.id,
              direction: 'pull',
              success: false,
              error: e.toString(),
            );
          }
        }
      } catch (e) {
        errors++;
        debugPrint('[SyncService] erro no pull -> $e');
        TelemetryService.instance.logSyncItem(
          'pull_batch',
          direction: 'pull',
          success: false,
          error: e.toString(),
        );
      }

      _hasCompletedAnySyncCycle = true;

      debugPrint(
        '[SyncService] concluido: pushed=$pushed pulled=$pulled errors=$errors',
      );
      TelemetryService.instance.logSyncCompleted(
        pushed: pushed,
        pulled: pulled,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    unbindOfflineMutationSync();
    _periodicTimer?.cancel();
  }
}
