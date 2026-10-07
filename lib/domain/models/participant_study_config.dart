/// Configuração remota do participante (Realtime Database: `participants/{id}`).
class ParticipantStudyConfig {
  static const String kOnlineFirst = 'online-first';
  static const String kOfflineFirst = 'offline-first';

  /// Perfil criado pelo painel admin; o participante deve confirmar no app.
  static const String kAdminProvisionedConsent = 'admin-provisioned';

  final String architecture;
  final bool appEnabled;
  final bool telemetryEnabled;
  final String? displayName;
  final int? daysOnlinePhase;
  final int? daysOfflinePhase;
  /// Início do experimento no RTDB (primeira ligação do participante), UTC.
  final DateTime? studyStartedAt;
  final Map<String, dynamic>? profileQuestionnaire;

  const ParticipantStudyConfig({
    required this.architecture,
    required this.appEnabled,
    required this.telemetryEnabled,
    this.displayName,
    this.daysOnlinePhase,
    this.daysOfflinePhase,
    this.studyStartedAt,
    this.profileQuestionnaire,
  });

  bool get isOnlineFirst => architecture == kOnlineFirst;
  bool get isOfflineFirst => architecture == kOfflineFirst;

  /// Nome atribuído ao código no cadastro (`display_name` ou `profile_questionnaire.name`).
  String? get registeredParticipantName {
    final dn = displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final pq = profileQuestionnaire;
    if (pq != null) {
      final n = pq['name']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }

  /// Perfil mínimo preenchido no RTDB (nome não vazio, idade, género, escolaridade).
  bool get profileComplete {
    final p = profileQuestionnaire;
    if (p == null) return false;
    final consentVer = p['consent_version']?.toString().trim() ?? '';
    if (consentVer == kAdminProvisionedConsent) return false;
    final name = p['name'];
    final age = p['age'];
    final gender = p['gender'];
    final education = p['education'];
    if (name == null || name.toString().trim().isEmpty) return false;
    if (age == null) return false;
    if (gender == null || gender.toString().isEmpty) return false;
    if (education == null || education.toString().isEmpty) return false;
    final consentAt = p['consent_accepted_at'];
    if (consentAt == null || consentAt.toString().trim().isEmpty) {
      return false;
    }
    if (consentVer.isEmpty) return false;
    return true;
  }

  factory ParticipantStudyConfig.fromRtdbMap(Map<dynamic, dynamic> raw) {
    final map = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k is String) map[k] = v;
    });
    return ParticipantStudyConfig.fromMap(map);
  }

  factory ParticipantStudyConfig.fromMap(Map<String, dynamic> map) {
    final arch = map['architecture'] as String? ?? kOnlineFirst;
    final normalized = arch == kOfflineFirst ? kOfflineFirst : kOnlineFirst;
    final startedRaw = map['study_started_at']?.toString();
    final started = startedRaw != null && startedRaw.trim().isNotEmpty
        ? DateTime.tryParse(startedRaw.trim())?.toUtc()
        : null;
    return ParticipantStudyConfig(
      architecture: normalized,
      appEnabled: _readBool(map['app_enabled'], fallback: true),
      telemetryEnabled: _readBool(map['telemetry_enabled'], fallback: true),
      displayName: map['display_name'] as String?,
      daysOnlinePhase: (map['days_online_phase'] as num?)?.toInt(),
      daysOfflinePhase: (map['days_offline_phase'] as num?)?.toInt(),
      studyStartedAt: started,
      profileQuestionnaire: _parseProfileMap(map['profile_questionnaire']),
    );
  }

  static Map<String, dynamic>? _parseProfileMap(Object? v) {
    if (v == null) return null;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }

  static bool _readBool(Object? v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return fallback;
  }

  /// Perfil mínimo marcado como completo (flavors legacy online/offline sem RTDB).
  factory ParticipantStudyConfig.legacyFlavor({required String architecture}) {
    final a = architecture == kOfflineFirst ? kOfflineFirst : kOnlineFirst;
    return ParticipantStudyConfig(
      architecture: a,
      appEnabled: true,
      telemetryEnabled: true,
      studyStartedAt: null,
      profileQuestionnaire: const {
        'name': '-',
        'age': 30,
        'gender': 'prefer_not',
        'education': 'edu_skip',
        'consent_version': 'legacy-dev',
        'consent_accepted_at': '1970-01-01T00:00:00.000Z',
      },
    );
  }

  /// Apenas desenvolvimento quando `ALLOW_MISSING_RTDB_PARTICIPANT=true`.
  factory ParticipantStudyConfig.developmentDefault(String participantId) {
    return ParticipantStudyConfig(
      architecture: kOnlineFirst,
      appEnabled: true,
      telemetryEnabled: true,
      displayName: participantId,
      studyStartedAt: null,
    );
  }
}
