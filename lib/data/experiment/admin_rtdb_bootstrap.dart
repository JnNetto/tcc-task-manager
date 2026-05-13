import 'package:firebase_database/firebase_database.dart';

import '../../config/debug_admin.dart';
import '../../domain/models/participant_study_config.dart';

/// Garante `study_config` e o nó do administrador [kDebugAdminParticipantId] no RTDB (idempotente).
class AdminRtdbBootstrap {
  AdminRtdbBootstrap._();

  static Future<void> ensureSeed(FirebaseDatabase db) async {
    final root = db.ref();

    final studySnap = await root.child('study_config').get();
    if (!studySnap.exists || studySnap.value == null) {
      await root.child('study_config').set({
        'total_study_days': 30,
        'days_per_architecture_default': 15,
      });
    }

    final adminRef = root.child('participants/$kDebugAdminParticipantId');
    final adminSnap = await adminRef.get();
    if (!adminSnap.exists || adminSnap.value == null) {
      await adminRef.set(_adminParticipantPayload());
      return;
    }
    final v = adminSnap.value;
    if (v is! Map) {
      await adminRef.set(_adminParticipantPayload());
      return;
    }
    final map = v.map((k, val) => MapEntry(k.toString(), val));
    if (map['architecture'] == null ||
        map['app_enabled'] == null ||
        map['profile_questionnaire'] == null) {
      await adminRef.update(_adminParticipantPayload());
    }
  }

  static Map<String, Object?> _adminParticipantPayload() => {
        'architecture': ParticipantStudyConfig.kOnlineFirst,
        'app_enabled': true,
        'telemetry_enabled': true,
        'display_name': 'Administrador (debug)',
        'days_online_phase': 0,
        'days_offline_phase': 0,
        'study_started_at': DateTime.now().toUtc().toIso8601String(),
        'profile_questionnaire': {
          'name': 'Administrador',
          'age': 30,
          'gender': 'prefer_not',
          'education': 'edu_skip',
          'consent_version': 'debug-admin',
          'consent_accepted_at': '1970-01-01T00:00:00.000Z',
        },
      };
}
