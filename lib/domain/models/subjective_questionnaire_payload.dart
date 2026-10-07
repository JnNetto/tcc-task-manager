import 'dart:convert';

import 'participant_study_config.dart';

/// Resposta subjetiva exportada pelos HTML `questionario_T1.html` / `questionario_T2.html`.
class SubjectiveQuestionnairePayload {
  const SubjectiveQuestionnairePayload({
    required this.raw,
    required this.participantId,
    required this.period,
    required this.submittedAt,
    required this.schemaVersion,
  });

  final Map<String, dynamic> raw;
  final String participantId;
  final String period;
  final String? submittedAt;
  final String schemaVersion;

  static const String kInstrument = 'questionario_periodo';
  static const Set<String> kAllowedPeriods = {'T1', 'T2'};

  /// Normaliza codigos como `P7`, `p007`, `007` para `P007`.
  static String? normalizeParticipantId(String raw) {
    final trimmed = raw.trim().toUpperCase();
    final match = RegExp(r'^P?(\d{1,3})$').firstMatch(trimmed);
    if (match == null) return null;
    final digits = match.group(1)!.padLeft(3, '0');
    return 'P$digits';
  }

  /// Arquitetura vigente no periodo do questionario.
  /// T1 = primeira fase (arquitetura atribuida no cadastro); T2 = fase oposta.
  static String architectureDuringPeriod({
    required String assignedArchitecture,
    required String period,
  }) {
    final first = assignedArchitecture == ParticipantStudyConfig.kOfflineFirst
        ? ParticipantStudyConfig.kOfflineFirst
        : ParticipantStudyConfig.kOnlineFirst;
    if (period == 'T1') return first;
    return first == ParticipantStudyConfig.kOnlineFirst
        ? ParticipantStudyConfig.kOfflineFirst
        : ParticipantStudyConfig.kOnlineFirst;
  }

  static SubjectiveQuestionnairePayload parse(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map) {
      throw FormatException('JSON invalido: campo "meta" ausente ou incorreto.');
    }
    final metaMap = _stringKeyedMap(meta);

    final instrument = metaMap['instrument']?.toString();
    if (instrument != kInstrument) {
      throw FormatException(
        'Instrumento desconhecido: "$instrument" (esperado "$kInstrument").',
      );
    }

    final period = metaMap['period']?.toString().trim().toUpperCase() ?? '';
    if (!kAllowedPeriods.contains(period)) {
      throw FormatException('Periodo invalido: "$period" (esperado T1 ou T2).');
    }

    final pidRaw = metaMap['participant_id']?.toString() ?? '';
    final participantId = normalizeParticipantId(pidRaw);
    if (participantId == null || participantId.isEmpty) {
      throw FormatException('Codigo de participante invalido: "$pidRaw".');
    }

    if (json['sus'] is! Map) {
      throw FormatException('JSON invalido: bloco "sus" ausente.');
    }

    if (period == 'T2' && json['comparative'] is! Map) {
      throw FormatException('Questionario T2 exige bloco "comparative".');
    }

    return SubjectiveQuestionnairePayload(
      raw: json,
      participantId: participantId,
      period: period,
      submittedAt: metaMap['submitted_at']?.toString(),
      schemaVersion: metaMap['schema_version']?.toString() ?? '1.0',
    );
  }

  static SubjectiveQuestionnairePayload parseJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw FormatException('JSON deve ser um objeto na raiz.');
    }
    return parse(_stringKeyedMap(decoded));
  }

  static Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> raw) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
}

/// Registro enriquecido gravado no RTDB para analise futura.
class SubjectiveQuestionnaireImportRecord {
  const SubjectiveQuestionnaireImportRecord({
    required this.period,
    required this.participantId,
    required this.participantDisplayName,
    required this.assignedArchitecture,
    required this.architectureDuringPeriod,
    required this.submittedAt,
    required this.importedAt,
    required this.schemaVersion,
    required this.responses,
  });

  final String period;
  final String participantId;
  final String participantDisplayName;
  /// Arquitetura atribuida no cadastro (primeira fase do estudo).
  final String assignedArchitecture;
  /// Arquitetura vigente nos 15 dias cobertos por este questionario.
  final String architectureDuringPeriod;
  final String? submittedAt;
  final String importedAt;
  final String schemaVersion;
  final Map<String, dynamic> responses;

  Map<String, dynamic> toMap() => {
        'period': period,
        'participant_id': participantId,
        'participant_display_name': participantDisplayName,
        'assigned_architecture': assignedArchitecture,
        'architecture_during_period': architectureDuringPeriod,
        'submitted_at': submittedAt,
        'imported_at': importedAt,
        'schema_version': schemaVersion,
        'responses': responses,
      };

  factory SubjectiveQuestionnaireImportRecord.fromMap(Map<String, dynamic> map) {
    final responses = map['responses'];
    return SubjectiveQuestionnaireImportRecord(
      period: map['period']?.toString() ?? '',
      participantId: map['participant_id']?.toString() ?? '',
      participantDisplayName:
          map['participant_display_name']?.toString() ?? '',
      assignedArchitecture:
          map['assigned_architecture']?.toString() ?? '',
      architectureDuringPeriod:
          map['architecture_during_period']?.toString() ?? '',
      submittedAt: map['submitted_at']?.toString(),
      importedAt: map['imported_at']?.toString() ?? '',
      schemaVersion: map['schema_version']?.toString() ?? '1.0',
      responses: responses is Map
          ? responses.map((k, v) => MapEntry(k.toString(), v))
          : const {},
    );
  }
}
