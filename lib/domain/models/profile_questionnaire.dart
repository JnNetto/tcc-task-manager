/// Respostas do questionário pós-código (persistido em RTDB).
class ProfileQuestionnaire {
  final String name;
  final int age;
  final String gender;
  final String education;

  /// Versão do texto de consentimento aceite (incrementar quando o texto legal mudar).
  final String consentVersion;

  /// Momento UTC em que o participante aceitou (ISO 8601).
  final String consentAcceptedAtIso;

  const ProfileQuestionnaire({
    required this.name,
    required this.age,
    required this.gender,
    required this.education,
    required this.consentVersion,
    required this.consentAcceptedAtIso,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender,
        'education': education,
        'consent_version': consentVersion,
        'consent_accepted_at': consentAcceptedAtIso,
      };
}
