import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/debug_admin.dart';
import '../../domain/models/participant_study_config.dart';

/// Linha da lista de participantes (dados em `participants/{id}`).
class AdminParticipantRow {
  const AdminParticipantRow({
    required this.id,
    required this.displayName,
    required this.architecture,
    required this.daysOnlinePhase,
    required this.daysOfflinePhase,
    required this.appEnabled,
    required this.telemetryEnabled,
  });

  final String id;
  final String displayName;
  final String architecture;
  final int daysOnlinePhase;
  final int daysOfflinePhase;
  final bool appEnabled;
  final bool telemetryEnabled;

  static AdminParticipantRow fromEntry(String id, Map<dynamic, dynamic> raw) {
    final map = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k is String) map[k] = v;
    });
    final cfg = ParticipantStudyConfig.fromMap(map);
    String name = cfg.displayName?.trim() ?? '';
    if (name.isEmpty) {
      final pq = map['profile_questionnaire'];
      if (pq is Map && pq['name'] != null) {
        name = pq['name'].toString().trim();
      }
    }
    if (name.isEmpty) name = id;
    return AdminParticipantRow(
      id: id,
      displayName: name,
      architecture: cfg.architecture,
      daysOnlinePhase: cfg.daysOnlinePhase ?? 0,
      daysOfflinePhase: cfg.daysOfflinePhase ?? 0,
      appEnabled: cfg.appEnabled,
      telemetryEnabled: cfg.telemetryEnabled,
    );
  }
}

/// Operações do painel investigador (RTDB). Usar apenas em [kDebugMode].
class AdminStudyRemoteService {
  AdminStudyRemoteService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _participants => _db.ref('participants');

  Future<List<AdminParticipantRow>> listParticipants() async {
    final snap = await _participants.get();
    if (!snap.exists || snap.value == null) return [];
    final v = snap.value;
    if (v is! Map) return [];
    final out = <AdminParticipantRow>[];
    v.forEach((k, val) {
      if (k is! String) return;
      if (val is Map) {
        out.add(AdminParticipantRow.fromEntry(k, val));
      }
    });
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  /// [digits] = 3 dígitos, ex. `001` → `P001`.
  Future<void> createParticipant({
    required String digits,
    required String displayName,
    required String architecture,
  }) async {
    final trimmed = digits.trim();
    if (!RegExp(r'^\d{3}$').hasMatch(trimmed)) {
      throw ArgumentError('Codigo deve ter exatamente 3 digitos (000-999).');
    }
    final id = 'P$trimmed';
    if (id == kDebugAdminParticipantId) {
      throw ArgumentError('Codigo reservado ao administrador (P000).');
    }
    final ref = _participants.child(id);
    final existing = await ref.get();
    if (existing.exists) {
      throw StateError('Ja existe participante com codigo $id.');
    }
    final arch = architecture == ParticipantStudyConfig.kOfflineFirst
        ? ParticipantStudyConfig.kOfflineFirst
        : ParticipantStudyConfig.kOnlineFirst;
    await ref.set({
      'architecture': arch,
      'app_enabled': true,
      'telemetry_enabled': true,
      'display_name': displayName.trim(),
      'days_online_phase': 0,
      'days_offline_phase': 0,
      'study_started_at': DateTime.now().toUtc().toIso8601String(),
      'profile_questionnaire': {
        'name': displayName.trim(),
        'age': 25,
        'gender': 'prefer_not',
        'education': 'edu_skip',
        'consent_version': 'admin-provisioned',
        'consent_accepted_at': DateTime.now().toUtc().toIso8601String(),
      },
    });
  }

  Future<void> updateArchitecture(String participantId, String architecture) {
    final arch = architecture == ParticipantStudyConfig.kOfflineFirst
        ? ParticipantStudyConfig.kOfflineFirst
        : ParticipantStudyConfig.kOnlineFirst;
    return _participants.child(participantId).update({'architecture': arch});
  }

  Future<void> updateFlags({
    required String participantId,
    required bool appEnabled,
    required bool telemetryEnabled,
  }) {
    return _participants.child(participantId).update({
      'app_enabled': appEnabled,
      'telemetry_enabled': telemetryEnabled,
    });
  }

  Future<void> updateDayCounters({
    required String participantId,
    required int daysOnline,
    required int daysOffline,
  }) {
    return _participants.child(participantId).update({
      'days_online_phase': daysOnline,
      'days_offline_phase': daysOffline,
    });
  }

  /// Exporta eventos de `telemetry/{id}` filtrados pelo campo `architecture`.
  Future<void> shareTelemetryExport({
    required String participantId,
    required String architectureFilter,
  }) async {
    final snap = await _db.ref('telemetry/$participantId').get();
    final events = <Map<String, dynamic>>[];
    if (snap.exists && snap.value is Map) {
      final map = Map<dynamic, dynamic>.from(snap.value! as Map);
      for (final e in map.values) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final arch = m['architecture']?.toString();
        if (arch == architectureFilter) {
          events.add(Map<String, dynamic>.from(m));
        }
      }
      events.sort((a, b) {
        final ta = a['timestamp']?.toString() ?? '';
        final tb = b['timestamp']?.toString() ?? '';
        return ta.compareTo(tb);
      });
    }

    final json = const JsonEncoder.withIndent('  ').convert({
      'metadata': {
        'export_timestamp': DateTime.now().toUtc().toIso8601String(),
        'participant_id': participantId,
        'filter_architecture': architectureFilter,
        'event_count': events.length,
      },
      'events': events,
    });

    final dir = await getApplicationDocumentsDirectory();
    final safe = participantId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File(
      '${dir.path}/telemetry_${safe}_${architectureFilter.replaceAll(RegExp(r'[^\w\-]'), '_')}.json',
    );
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Telemetria $participantId ($architectureFilter)',
      ),
    );
  }
}
