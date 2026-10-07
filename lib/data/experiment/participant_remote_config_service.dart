import 'package:firebase_database/firebase_database.dart';

import '../../domain/models/participant_study_config.dart';
import '../../domain/models/profile_questionnaire.dart';
import 'participant_phase_day_tally.dart' show buildPhaseDayTallyUpdate;

/// Leitura/escrita de configuração do participante no Realtime Database.
/// Não utiliza [NetworkSimulator] — chamadas diretas ao SDK.
class ParticipantRemoteConfigService {
  ParticipantRemoteConfigService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Quando `true` e o nó não existir, devolve [ParticipantStudyConfig.developmentDefault] (só para debug).
  static const bool allowMissingParticipant = bool.fromEnvironment(
    'ALLOW_MISSING_RTDB_PARTICIPANT',
    defaultValue: false,
  );

  DatabaseReference participantRef(String participantId) =>
      _db.ref('participants/$participantId');

  Future<ParticipantStudyConfig?> fetchParticipant(String participantId) async {
    final snap = await participantRef(participantId).get();
    if (!snap.exists || snap.value == null) {
      if (allowMissingParticipant) {
        return ParticipantStudyConfig.developmentDefault(participantId);
      }
      return null;
    }
    final value = snap.value;
    if (value is! Map) return null;
    return ParticipantStudyConfig.fromRtdbMap(value);
  }

  Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Garante [study_started_at] na primeira ligação, linha temporal mínima e contadores
  /// de dias por modo (UTC). Deve ser chamado após [fetchParticipant] com sucesso.
  Future<ParticipantStudyConfig> ensureEnrollmentMetaAndPhaseTally(
    String participantId,
  ) async {
    final ref = participantRef(participantId);
    var snap = await ref.get();
    if (!snap.exists || snap.value is! Map) {
      if (allowMissingParticipant) {
        return ParticipantStudyConfig.developmentDefault(participantId);
      }
      throw StateError('Participante inexistente: $participantId');
    }

    var map = _stringKeyedMap(snap.value);

    final startedRaw = map['study_started_at']?.toString().trim() ?? '';
    if (startedRaw.isEmpty) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await ref.update({'study_started_at': nowIso});
      map['study_started_at'] = nowIso;
    }

    final tl = map['architecture_timeline'];
    if (tl is! Map || tl.isEmpty) {
      final cfg = ParticipantStudyConfig.fromMap(map);
      await ref.child('architecture_timeline').push().set({
        'changed_at': map['study_started_at'],
        'architecture': cfg.architecture,
      });
      snap = await ref.get();
      if (!snap.exists || snap.value is! Map) {
        if (allowMissingParticipant) {
          return ParticipantStudyConfig.developmentDefault(participantId);
        }
        throw StateError('Participante inexistente apos escrita: $participantId');
      }
      map = _stringKeyedMap(snap.value);
    }

    final tallyPatch = buildPhaseDayTallyUpdate(map);
    if (tallyPatch != null) {
      await ref.update(tallyPatch);
      snap = await ref.get();
      if (!snap.exists || snap.value is! Map) {
        if (allowMissingParticipant) {
          return ParticipantStudyConfig.developmentDefault(participantId);
        }
        throw StateError('Participante inexistente apos tally: $participantId');
      }
      map = _stringKeyedMap(snap.value);
    }

    return ParticipantStudyConfig.fromMap(map);
  }

  Future<void> saveProfileQuestionnaire(
    String participantId,
    ProfileQuestionnaire answers,
  ) async {
    await participantRef(participantId).update({
      'profile_questionnaire': answers.toMap(),
      'display_name': answers.name,
    });
  }
}
