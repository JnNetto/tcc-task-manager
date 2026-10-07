import '../../domain/models/participant_study_config.dart';

/// Data civil em UTC (sem componente horário).
DateTime utcDateOnly(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

DateTime? _parseIsoUtc(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim())?.toUtc();
}

DateTime? _parseUtcYmd(String s) {
  final p = s.trim().split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final mo = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || mo == null || d == null) return null;
  return DateTime.utc(y, mo, d);
}

String _normalizeArch(String? v) =>
    v == ParticipantStudyConfig.kOfflineFirst
        ? ParticipantStudyConfig.kOfflineFirst
        : ParticipantStudyConfig.kOnlineFirst;

/// Arquitetura vigente no instante [t] (UTC), usando a linha temporal e o valor atual do nó.
String architectureAtInstant(
  Map<String, dynamic> m,
  DateTime t,
  DateTime studyStartedFull,
) {
  if (t.isBefore(studyStartedFull)) {
    return _normalizeArch(m['architecture']?.toString());
  }
  final tl = m['architecture_timeline'];
  final entries = <({DateTime at, String arch})>[];
  if (tl is Map) {
    for (final v in tl.values) {
      if (v is! Map) continue;
      final at = _parseIsoUtc(v['changed_at']?.toString());
      if (at == null) continue;
      entries.add((at: at, arch: _normalizeArch(v['architecture']?.toString())));
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
  }
  String? last;
  for (final e in entries) {
    if (e.at.isAfter(t)) break;
    last = e.arch;
  }
  return last ?? _normalizeArch(m['architecture']?.toString());
}

/// Calcula `days_online_phase`, `days_offline_phase` e `last_phase_tally_utc_date`
/// com base em [study_started_at] e na linha temporal. Devolve `null` se não houver
/// alterações a gravar.
Map<String, Object?>? buildPhaseDayTallyUpdate(Map<String, dynamic> m) {
  final studyStarted = _parseIsoUtc(m['study_started_at']?.toString());
  if (studyStarted == null) return null;

  final today = utcDateOnly(DateTime.now().toUtc());
  final lastRaw = m['last_phase_tally_utc_date']?.toString().trim() ?? '';
  final lastDay = lastRaw.isEmpty ? null : _parseUtcYmd(lastRaw);
  final studyFirstDay = utcDateOnly(studyStarted);

  final DateTime firstToCount;
  if (lastDay == null) {
    firstToCount = studyFirstDay;
  } else {
    firstToCount = lastDay.add(const Duration(days: 1));
  }
  if (firstToCount.isAfter(today)) return null;

  var dOn = (m['days_online_phase'] as num?)?.toInt() ?? 0;
  var dOff = (m['days_offline_phase'] as num?)?.toInt() ?? 0;

  for (var d = firstToCount; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
    final noon = DateTime.utc(d.year, d.month, d.day, 12);
    final arch = architectureAtInstant(m, noon, studyStarted);
    if (arch == ParticipantStudyConfig.kOfflineFirst) {
      dOff++;
    } else {
      dOn++;
    }
  }

  final prevOn = (m['days_online_phase'] as num?)?.toInt() ?? 0;
  final prevOff = (m['days_offline_phase'] as num?)?.toInt() ?? 0;
  final prevLast = lastRaw;
  final newLast =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  if (prevOn == dOn && prevOff == dOff && prevLast == newLast) {
    return null;
  }

  return <String, Object?>{
    'days_online_phase': dOn,
    'days_offline_phase': dOff,
    'last_phase_tally_utc_date': newLast,
  };
}
