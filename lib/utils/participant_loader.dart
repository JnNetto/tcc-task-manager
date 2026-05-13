import 'package:shared_preferences/shared_preferences.dart';

Future<String?> loadParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  final override =
      const String.fromEnvironment('PARTICIPANT_ID', defaultValue: '').trim();
  if (override.isNotEmpty) {
    await prefs.setString('participant_id', override);
    return override;
  }

  final existing = prefs.getString('participant_id');
  if (existing != null && existing.trim().isNotEmpty) {
    return existing.trim();
  }
  return null;
}

String buildParticipantIdFromNumber(String number3Digits) =>
    'P$number3Digits';

Future<void> saveParticipantId(String participantId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('participant_id', participantId);
}

Future<DateTime> loadStudyStartDate() async {
  final prefs = await SharedPreferences.getInstance();
  final iso = prefs.getString('study_start_date');
  if (iso != null) return DateTime.parse(iso);
  final now = DateTime.now();
  await prefs.setString('study_start_date', now.toIso8601String());
  return now;
}
