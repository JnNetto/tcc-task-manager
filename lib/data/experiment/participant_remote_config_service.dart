import 'package:firebase_database/firebase_database.dart';

import '../../domain/models/participant_study_config.dart';
import '../../domain/models/profile_questionnaire.dart';

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
