import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/sync_status.dart';
import '../../domain/models/task.dart';
import '../../services/network_simulator.dart';
import '../../services/telemetry_service.dart';
import 'offline_task_repository.dart';

class SyncService {
  final OfflineTaskRepository _local;
  final FirebaseFirestore _firestore;
  final String participantId;
  bool _isSyncing = false;
  Timer? _periodicTimer;
  static const _lastPullKey = 'last_pull_at';

  SyncService({
    required OfflineTaskRepository localRepo,
    required this.participantId,
    FirebaseFirestore? firestore,
  }) : _local = localRepo,
       _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('participants').doc(participantId).collection('tasks');

  void start() {
    debugPrint('[SyncService] start() - participantId=$participantId');
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncIfAllowed(),
    );
    _syncIfAllowed();
  }

  Future<void> syncNow() => _syncIfAllowed();

  Future<void> _syncIfAllowed() async {
    if (_isSyncing) {
      debugPrint('[SyncService] skip: sync ja em execucao');
      return;
    }

    final allowed = await NetworkSimulator.instance.checkSyncAllowed(
      'sync_service',
    );

    if (!allowed) {
      debugPrint('[SyncService] bloqueado pelo NetworkSimulator (janela ativa)');
      return;
    }

    debugPrint('[SyncService] permitido, iniciando _doSync()');
    await _doSync();
  }

  Future<void> _doSync() async {
    _isSyncing = true;
    try {
      final pending = _local.getPending();
      final prefs = await SharedPreferences.getInstance();
      final lastPullRaw = prefs.getString(_lastPullKey);
      final lastPullAt = lastPullRaw != null ? DateTime.tryParse(lastPullRaw) : null;

      debugPrint(
        '[SyncService] pendentes=${pending.length} lastPull=${lastPullAt?.toIso8601String() ?? 'null'}',
      );

      TelemetryService.instance.logSyncStarted(
        pendingCount: pending.length,
        isFirstSync: lastPullAt == null,
      );

      int pushed = 0;
      int pulled = 0;
      int errors = 0;

      // PUSH (local -> remoto)
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

      // PULL (remoto -> local)
      try {
        final pullStart = DateTime.now();
        Query<Map<String, dynamic>> query = _col;
        if (lastPullAt != null) {
          query = query.where(
            'updatedAt',
            isGreaterThan: Timestamp.fromDate(lastPullAt),
          );
        }

        final snapshot = await query.get();
        debugPrint('[SyncService] pull docs=${snapshot.docs.length}');

        for (final doc in snapshot.docs) {
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
              local.syncStatus == SyncStatus.deleted;

          if (remote.updatedAt.isAfter(local.updatedAt) && !localHasUnsynced) {
            await _local.updateTaskFromRemote(remote);
            pulled++;
            TelemetryService.instance.logSyncItem(
              remote.id,
              direction: 'pull',
              success: true,
            );
          }
        }

        await prefs.setString(_lastPullKey, pullStart.toIso8601String());
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
    _periodicTimer?.cancel();
  }
}
