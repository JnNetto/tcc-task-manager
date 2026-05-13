import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/hive/telemetry_event_model.dart';
import 'network_simulator.dart';

class TelemetryService {
  static final TelemetryService instance = TelemetryService._();
  TelemetryService._();

  late Box<TelemetryEventModel> _box;
  late String _participantId;
  late String _fixedPrototypeFallback;
  late DateTime _studyStartDate;
  String _sessionId = '';
  int _seq = 0;
  final _uuid = const Uuid();

  DatabaseReference? _telemetryBranchRef;
  String Function()? _architectureResolver;
  bool Function()? _telemetryEnabledResolver;

  Future<void> init({
    required String participantId,
    required String prototype,
    required DateTime studyStartDate,
    FirebaseDatabase? realtimeDatabase,
    String Function()? architectureResolver,
    bool Function()? telemetryEnabledResolver,
  }) async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TelemetryEventModelAdapter());
    }

    _box = await Hive.openBox<TelemetryEventModel>('telemetry');
    _participantId = participantId;
    _fixedPrototypeFallback = prototype;
    _studyStartDate = studyStartDate;
    _architectureResolver = architectureResolver;
    _telemetryEnabledResolver = telemetryEnabledResolver;
    _sessionId = _uuid.v4();

    if (realtimeDatabase != null) {
      _telemetryBranchRef = realtimeDatabase.ref('telemetry/$participantId');
    }

    logEvent(
      'session_started',
      data: {
        'participant_id': participantId,
        'architecture': _currentArchitecture,
        'study_start': studyStartDate.toIso8601String(),
      },
    );
  }

  String get _currentArchitecture =>
      _architectureResolver?.call() ?? _fixedPrototypeFallback;

  bool get _telemetryAllowed => _telemetryEnabledResolver?.call() ?? true;

  int get _dayOfStudy => DateTime.now().difference(_studyStartDate).inDays + 1;

  void logEvent(String type, {Map<String, dynamic>? data}) {
    if (!_telemetryAllowed) return;

    final arch = _currentArchitecture;
    final model = TelemetryEventModel(
      id: _uuid.v4(),
      participantId: _participantId,
      sessionId: _sessionId,
      eventType: type,
      timestamp: DateTime.now(),
      data: data,
      prototype: arch,
      networkDegraded: NetworkSimulator.instance.isDegraded,
      sequenceNumber: _seq++,
      dayOfStudy: _dayOfStudy,
    );
    _box.add(model);

    final remote = _telemetryBranchRef;
    if (remote != null) {
      unawaited(_pushRemote(model));
    }
  }

  Future<void> _pushRemote(TelemetryEventModel e) async {
    try {
      final payload = <String, dynamic>{
        'id': e.id,
        'participantId': e.participantId,
        'sessionId': e.sessionId,
        'eventType': e.eventType,
        'timestamp': e.timestamp.toUtc().toIso8601String(),
        'data': e.data,
        'architecture': e.prototype,
        'networkDegraded': e.networkDegraded,
        'sequenceNumber': e.sequenceNumber,
        'dayOfStudy': e.dayOfStudy,
      };
      await _telemetryBranchRef!.push().set(payload);
    } catch (err, st) {
      if (kDebugMode) {
        debugPrint('TelemetryService RTDB push failed: $err\n$st');
      }
    }
  }

  void logOperationStarted(String op, String taskId) {
    logEvent('operation_started', data: {'op': op, 'task_id': taskId});
  }

  void logOperationCompleted(
    String op,
    String taskId, {
    required bool success,
    bool local = false,
    String? error,
  }) {
    logEvent(
      'operation_completed',
      data: {
        'op': op,
        'task_id': taskId,
        'success': success,
        'local': local,
        if (error != null) 'error': error,
      },
    );
  }

  void logOperationBlocked(String op, {String? cause}) {
    logEvent(
      'operation_blocked',
      data: {
        'op': op,
        'reason': 'network_simulator',
        if (cause != null) 'cause': cause,
      },
    );
  }

  void logOperationDelayed(String op, int latencyMs, {String? cause}) {
    logEvent(
      'operation_delayed',
      data: {
        'op': op,
        'latency_ms': latencyMs,
        if (cause != null) 'cause': cause,
      },
    );
  }

  void logAbandonAfterFailure(String op) {
    logEvent('abandon_after_failure', data: {'op': op});
  }

  void logSyncStarted({required int pendingCount, bool isFirstSync = false}) {
    logEvent(
      'sync_started',
      data: {
        'pending_count': pendingCount,
        'is_first_sync': isFirstSync,
      },
    );
  }

  void logSyncCompleted({
    required int pushed,
    required int pulled,
    required int errors,
    String? pullError,
  }) {
    logEvent(
      'sync_completed',
      data: {
        'pushed': pushed,
        'pulled': pulled,
        'errors': errors,
        if (pullError != null) 'pull_error': pullError,
      },
    );
  }

  void logSyncBlocked({String? reason}) {
    logEvent('sync_blocked', data: {if (reason != null) 'reason': reason});
  }

  void logSyncItem(
    String taskId, {
    required String direction,
    required bool success,
    Duration? pendingDuration,
    String? error,
  }) {
    logEvent(
      'sync_item',
      data: {
        'task_id': taskId,
        'direction': direction,
        'success': success,
        if (pendingDuration != null)
          'pending_duration_ms': pendingDuration.inMilliseconds,
        if (error != null) 'error': error,
      },
    );
  }

  void logNetworkWindowChanged({
    required bool degraded,
    String? cause,
    required DateTime timestamp,
  }) {
    logEvent(
      'network_window_changed',
      data: {
        'degraded': degraded,
        if (cause != null) 'cause': cause,
        'timestamp': timestamp.toIso8601String(),
      },
    );
  }

  void newSession() {
    _sessionId = _uuid.v4();
    logEvent('session_started');
  }

  Future<String> exportToJson() async {
    final events = _box.values.toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return const JsonEncoder.withIndent('  ').convert(
      {
        'metadata': {
          'export_timestamp': DateTime.now().toIso8601String(),
          'participant_id': _participantId,
          'prototype': _currentArchitecture,
          'study_start_date': _studyStartDate.toIso8601String(),
          'total_days': _dayOfStudy,
          'total_events': events.length,
        },
        'summary': _buildSummary(events),
        'daily_breakdown': _buildDailyBreakdown(events),
        'events': events.map((e) => e.toJson()).toList(),
      },
    );
  }

  Map<String, dynamic> _buildSummary(List<TelemetryEventModel> events) {
    final completed = events.where((e) => e.eventType == 'operation_completed');
    final successful = completed.where((e) => e.data?['success'] == true);
    final blocked = events.where((e) => e.eventType == 'operation_blocked');
    final delayed = events.where((e) => e.eventType == 'operation_delayed');
    final abandoned =
        events.where((e) => e.eventType == 'abandon_after_failure');
    final syncItems = events.where((e) => e.eventType == 'sync_item');
    final syncPush = syncItems.where((e) => e.data?['direction'] == 'push');
    final syncPull = syncItems.where((e) => e.data?['direction'] == 'pull');
    final syncPushOk = syncPush.where((e) => e.data?['success'] == true);
    final syncPullOk = syncPull.where((e) => e.data?['success'] == true);
    final syncOk = syncItems.where((e) => e.data?['success'] == true);

    final pendingDurations = syncOk
        .where((e) => e.data?['pending_duration_ms'] != null)
        .map((e) => e.data!['pending_duration_ms'] as int)
        .toList();

    return {
      'operation_success_rate': completed.isEmpty
          ? null
          : successful.length / completed.length,
      'operations_blocked_total': blocked.length,
      'operations_delayed_total': delayed.length,
      'abandon_after_failure_total': abandoned.length,
      'sync_push_success_rate': syncPush.isEmpty
          ? null
          : syncPushOk.length / syncPush.length,
      'sync_pull_success_rate': syncPull.isEmpty
          ? null
          : syncPullOk.length / syncPull.length,
      'sync_success_rate': syncItems.isEmpty ? null : syncOk.length / syncItems.length,
      'avg_pending_to_sync_ms': pendingDurations.isEmpty
          ? null
          : pendingDurations.reduce((a, b) => a + b) / pendingDurations.length,
      'total_operations': completed.length,
    };
  }

  Map<String, dynamic> _buildDailyBreakdown(List<TelemetryEventModel> events) {
    final byDay = <int, List<TelemetryEventModel>>{};
    for (final e in events) {
      byDay.putIfAbsent(e.dayOfStudy, () => []).add(e);
    }

    return byDay.map((day, dayEvents) {
      final completed = dayEvents.where((e) => e.eventType == 'operation_completed');
      final blocked = dayEvents.where((e) => e.eventType == 'operation_blocked');
      return MapEntry(
        'day_$day',
        {
          'total_operations': completed.length,
          'operations_blocked': blocked.length,
          'sessions': dayEvents.where((e) => e.eventType == 'session_started').length,
        },
      );
    });
  }

  Future<void> clearAll() async {
    await _box.clear();
    _seq = 0;
  }
}
