import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../services/network_simulator.dart';
import '../services/telemetry_service.dart';

/// Grava impressões imediatas no documento Firestore `participants/{id}`.
class ParticipantImpressionService {
  ParticipantImpressionService({
    required this.participantId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String participantId;
  final FirebaseFirestore _firestore;

  static const _fieldName = 'immediate_impressions';
  static const _maxTextLength = 2000;

  DocumentReference<Map<String, dynamic>> get _participantDoc =>
      _firestore.collection('participants').doc(participantId);

  Future<void> submitImpression({
    required String text,
    required String architecture,
    required int studyDay,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('O comentario nao pode estar vazio.');
    }
    if (trimmed.length > _maxTextLength) {
      throw ArgumentError(
        'O comentario pode ter no maximo $_maxTextLength caracteres.',
      );
    }

    final entry = <String, dynamic>{
      'id': const Uuid().v4(),
      'text': trimmed,
      'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'architecture': architecture,
      'studyDay': studyDay,
    };

    await NetworkSimulator.instance.intercept('submit_impression', () async {
      TelemetryService.instance.logOperationStarted(
        'submit_impression',
        entry['id'] as String,
      );
      try {
        await _participantDoc.set(
          {_fieldName: FieldValue.arrayUnion([entry])},
          SetOptions(merge: true),
        );
        TelemetryService.instance.logEvent(
          'participant_impression_submitted',
          data: {
            'architecture': architecture,
            'studyDay': studyDay,
            'length': trimmed.length,
          },
        );
        TelemetryService.instance.logOperationCompleted(
          'submit_impression',
          entry['id'] as String,
          success: true,
        );
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
          'submit_impression',
          entry['id'] as String,
          success: false,
          error: e.code,
        );
        rethrow;
      }
    });
  }
}
