import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'annotation_alarm_channel';
  static const _channelName = 'Lembretes de Anotações';
  static const _channelDesc =
      'Notificações de lembretes para suas anotações específicas';
  static const _kRecurringConfigsKey = 'recurring_notification_configs';

  // Janela de pré-agendamento por tipo de recorrência.
  // Alarmes passados são limpos automaticamente pelo AlarmManager,
  // e a janela é renovada pelo refill quando restar < 7 dias.
  static const _kDailyWindowDays = 30; // 1 mês (~30 alarmes por horário)
  static const _kWeeklyWindowDays = 84; // 12 semanas
  static const _kMonthlyWindowMonths = 24; // 2 anos

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static bool _inited = false;

  static Future<void> initialize() async {
    if (_inited) return;
    try {
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings(
        '@drawable/notification_icon',
      );
      const initSettings = InitializationSettings(android: androidInit);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
        await android.requestNotificationsPermission();
      }

      _inited = true;
      debugPrint('NotificationService inicializado');
      await performMaintenanceCleanup();
    } catch (e) {
      debugPrint('Erro na inicialização de notificações: $e');
      _inited = true;
    }
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint('Notificação tocada: ${response.payload}');
  }

  // ====== Permissões ======

  static Future<bool> _ensureNotificationsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão: $e');
      return false;
    }
  }

  static Future<bool> _canScheduleExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    try {
      return await android.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      return await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  // ====== API principal ======

  static Future<void> scheduleNotificationForAnnotation(
    Annotation annotation,
    String cardTitle,
  ) async {
    await initialize();

    final hasNotifPerm = await _ensureNotificationsPermission();
    if (!hasNotifPerm) {
      debugPrint('POST_NOTIFICATIONS negada. Notificação não agendada.');
      return;
    }

    final notifEnabled = await _areNotificationsEnabled();
    if (!notifEnabled) {
      debugPrint('Canal de notificações desativado pelo usuário.');
    }

    await cancelAnnotationNotification(annotation.id);

    if (annotation.reminderSettings.recurrenceType == RecurrenceType.none) {
      if (annotation.alarmDateTime == null) return;
      await _scheduleSingleNotification(annotation, cardTitle);
      return;
    }

    await _scheduleRecurringWithExactAlarms(annotation, cardTitle);
  }

  // ====== Notificação única (AlarmManager exato) ======

  static Future<void> _scheduleSingleNotification(
    Annotation annotation,
    String cardTitle,
  ) async {
    if (annotation.alarmDateTime == null) return;

    final scheduledDate = tz.TZDateTime.from(
      annotation.alarmDateTime!,
      tz.local,
    );
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final notificationData = _getNotificationContent(annotation, cardTitle);
    const details = NotificationDetails(android: _androidDetails);

    try {
      final id = _stableId('single:${annotation.id}');
      await _plugin.zonedSchedule(
        id,
        notificationData['title'],
        notificationData['body'],
        scheduledDate,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'annotation:${annotation.id}',
      );
      debugPrint(
        'Notificação única agendada: ${annotation.id} em $scheduledDate',
      );
    } catch (e) {
      debugPrint('Falha ao agendar notificação única: $e');
      rethrow;
    }
  }

  // ====== Notificações recorrentes via AlarmManager exato ======
  //
  // Pré-agenda todas as ocorrências dentro de uma janela de tempo
  // usando flutter_local_notifications com exactAllowWhileIdle.
  // Na manutenção (initialize), a janela é renovada automaticamente.

  static Future<void> _scheduleRecurringWithExactAlarms(
    Annotation annotation,
    String cardTitle,
  ) async {
    final s = annotation.reminderSettings;
    if (s.dailyTimes.isEmpty || s.recurrenceType == RecurrenceType.none) return;

    final now = DateTime.now();
    if (s.endDate != null && now.isAfter(s.endDate!)) {
      debugPrint(
        'Recorrência encerrada para ${annotation.id} — passou do endDate',
      );
      return;
    }

    final notifData = _getNotificationContent(annotation, cardTitle);
    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(android: _androidDetails);
    final occurrences = _computeOccurrences(s, now);
    final scheduledIds = <int>[];
    DateTime? scheduledUntil;

    for (final occ in occurrences) {
      final scheduledDate = tz.TZDateTime.from(occ.dateTime, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final key =
          'recurring:${annotation.id}:${occ.dateTime.toIso8601String()}';
      final id = _stableId(key);

      try {
        await _plugin.zonedSchedule(
          id,
          '${notifData['title']} (${_formatTimeOfDay(occ.time)})',
          notifData['body']!,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'annotation:${annotation.id}',
        );
        scheduledIds.add(id);
        if (scheduledUntil == null || occ.dateTime.isAfter(scheduledUntil)) {
          scheduledUntil = occ.dateTime;
        }
        debugPrint('Agendado: ${annotation.id} em ${occ.dateTime}');
      } catch (e) {
        debugPrint('Falha ao agendar ocorrência ${occ.dateTime}: $e');
      }
    }

    await _saveRecurringConfig(
      annotation.id,
      scheduledIds,
      s.endDate,
      scheduledUntil,
      notifData['title']!,
      notifData['body']!,
      s,
    );
    debugPrint(
      '${scheduledIds.length} ocorrências agendadas para ${annotation.id}',
    );
  }

  // ====== Cálculo de ocorrências ======

  static List<_Occurrence> _computeOccurrences(
    ReminderSettings s,
    DateTime from,
  ) {
    final result = <_Occurrence>[];
    final endDate = s.endDate;

    bool withinRange(DateTime dt) {
      if (!dt.isAfter(from)) return false;
      if (endDate != null && dt.isAfter(endDate)) return false;
      return true;
    }

    switch (s.recurrenceType) {
      case RecurrenceType.daily:
        for (int offset = 0; offset < _kDailyWindowDays; offset++) {
          final date = from.add(Duration(days: offset));
          for (final time in s.dailyTimes) {
            final dt = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            if (withinRange(dt)) result.add(_Occurrence(dt, time));
          }
        }
        break;

      case RecurrenceType.weekly:
        final days = s.weekdays.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : s.weekdays;
        for (int offset = 0; offset < _kWeeklyWindowDays; offset++) {
          final date = from.add(Duration(days: offset));
          if (!days.contains(date.weekday)) continue;
          for (final time in s.dailyTimes) {
            final dt = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            if (withinRange(dt)) result.add(_Occurrence(dt, time));
          }
        }
        break;

      case RecurrenceType.monthly:
        final targetDay = s.monthDay ?? from.day;
        for (
          int monthOffset = 0;
          monthOffset < _kMonthlyWindowMonths;
          monthOffset++
        ) {
          int m = from.month + monthOffset;
          int y = from.year + (m - 1) ~/ 12;
          m = ((m - 1) % 12) + 1;
          final lastDay = DateTime(y, m + 1, 0).day;
          final d = targetDay > lastDay ? lastDay : targetDay;
          for (final time in s.dailyTimes) {
            final dt = DateTime(y, m, d, time.hour, time.minute);
            if (withinRange(dt)) result.add(_Occurrence(dt, time));
          }
        }
        break;

      default:
        break;
    }

    return result;
  }

  // ====== Persistência de configs recorrentes ======

  static Future<void> _saveRecurringConfig(
    String annotationId,
    List<int> notifIds,
    DateTime? endDate,
    DateTime? scheduledUntil,
    String notifTitle,
    String notifBody,
    ReminderSettings s,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
      final configs = jsonDecode(raw) as Map<String, dynamic>;
      configs[annotationId] = {
        'ids': notifIds,
        'endDate': endDate?.toIso8601String(),
        'scheduledUntil': scheduledUntil?.toIso8601String(),
        'notifTitle': notifTitle,
        'notifBody': notifBody,
        'recurrenceType': s.recurrenceType.name,
        'dailyTimes': s.dailyTimes
            .map((t) => {'hour': t.hour, 'minute': t.minute})
            .toList(),
        'weekdays': s.weekdays.toList(),
        'monthDay': s.monthDay,
      };
      await prefs.setString(_kRecurringConfigsKey, jsonEncode(configs));
    } catch (e) {
      debugPrint('Erro ao salvar config recorrente: $e');
    }
  }

  static Future<void> _removeRecurringConfig(String annotationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
      final configs = jsonDecode(raw) as Map<String, dynamic>;
      configs.remove(annotationId);
      await prefs.setString(_kRecurringConfigsKey, jsonEncode(configs));
    } catch (e) {
      debugPrint('Erro ao remover config recorrente: $e');
    }
  }

  static Future<Map<String, dynamic>> _loadRecurringConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Erro ao carregar configs recorrentes: $e');
      return {};
    }
  }

  static ReminderSettings? _reminderSettingsFromConfig(
    Map<String, dynamic> config,
  ) {
    try {
      final rtStr = config['recurrenceType'] as String?;
      if (rtStr == null) return null;
      final rt = RecurrenceType.values.firstWhere(
        (e) => e.name == rtStr,
        orElse: () => RecurrenceType.none,
      );
      final timesRaw = config['dailyTimes'] as List? ?? [];
      final times = timesRaw
          .map(
            (t) => TimeOfDay(
              hour: (t as Map)['hour'] as int,
              minute: t['minute'] as int,
            ),
          )
          .toList();
      final weekdays = Set<int>.from(
        (config['weekdays'] as List? ?? []).cast<int>(),
      );
      final monthDay = config['monthDay'] as int?;
      final endDateStr = config['endDate'] as String?;
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      return ReminderSettings(
        recurrenceType: rt,
        dailyTimes: times,
        weekdays: weekdays,
        monthDay: monthDay,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Erro ao reconstruir ReminderSettings: $e');
      return null;
    }
  }

  // ====== Conteúdo / utilitários ======

  static Map<String, String> _getNotificationContent(
    dynamic annotationOrId,
    String cardTitle,
  ) {
    String title = '🔔 Lembrete';
    String body = 'Card: $cardTitle';

    if (annotationOrId is Annotation) {
      if (annotationOrId is TextAnnotation) {
        title = '📝 Lembrete: Anotação de Texto';
        final txt = annotationOrId.content;
        final preview = txt.length > 50 ? '${txt.substring(0, 50)}...' : txt;
        body = 'Card: $cardTitle\nTexto: $preview';
      } else if (annotationOrId is ChecklistAnnotation) {
        title = '✅ Lembrete: Lista de Tarefas';
        body = 'Card: $cardTitle\nLista: ${annotationOrId.title}';
      } else if (annotationOrId is FileAnnotation) {
        title = '📎 Lembrete: Arquivo';
        body = 'Card: $cardTitle\nArquivo: ${annotationOrId.fileName}';
      }
    } else {
      title = '🔔 Lembrete Recorrente';
      body = 'Card: $cardTitle\nHora do seu lembrete!';
    }

    return {'title': title, 'body': body};
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
    icon: 'notification_icon',
  );

  // ====== Cancelamentos e consultas ======

  static Future<void> cancelNotification(String cardId) async {
    await _plugin.cancel(_stableId('single:$cardId'));
  }

  static Future<void> cancelAnnotationNotification(String annotationId) async {
    // 1. Cancelar a notificação única (caso exista)
    await _plugin.cancel(_stableId('single:$annotationId'));

    // 2. Cancelar todos os IDs registrados na config recorrente
    final configs = await _loadRecurringConfigs();
    final config = configs[annotationId] as Map<String, dynamic>?;
    if (config != null) {
      final notifIds = (config['ids'] as List? ?? []).cast<int>();
      for (final id in notifIds) {
        await _plugin.cancel(id);
      }
    }

    // 3. REDE DE SEGURANÇA: varrer pendentes e cancelar qualquer
    //    notificação órfã que carregue o payload desta anotação.
    //    Isso pega notificações que vazaram em versões anteriores do app
    //    ou em casos de dessincronização entre SharedPreferences e AlarmManager.
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final targetPayload = 'annotation:$annotationId';
      int orphanCount = 0;
      for (final p in pending) {
        if (p.payload == targetPayload) {
          await _plugin.cancel(p.id);
          orphanCount++;
        }
      }
      if (orphanCount > 0) {
        debugPrint(
          'Canceladas $orphanCount notificações órfãs de $annotationId',
        );
      }
    } catch (e) {
      debugPrint('Erro ao varrer notificações órfãs: $e');
    }

    // 4. Remover a entrada do SharedPreferences
    await _removeRecurringConfig(annotationId);
    debugPrint('Notificações canceladas para $annotationId');
  }

  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecurringConfigsKey);
    } catch (e) {
      debugPrint('Erro ao limpar configs: $e');
    }
    debugPrint('Todas as notificações canceladas');
  }

  static Future<bool> hasActiveNotification(String annotationId) async {
    final pending = await _plugin.pendingNotificationRequests();
    final pendingIds = pending.map((n) => n.id).toSet();

    if (pendingIds.contains(_stableId('single:$annotationId'))) return true;

    final configs = await _loadRecurringConfigs();
    if (!configs.containsKey(annotationId)) return false;
    final config = configs[annotationId] as Map<String, dynamic>;
    final ids = (config['ids'] as List? ?? []).cast<int>();
    return ids.any((id) => pendingIds.contains(id));
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  // ====== Limpeza / manutenção ======

  static Future<void> cleanupOldNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      int cleaned = 0;
      for (final n in pending) {
        if (n.title == null ||
            n.title!.isEmpty ||
            (n.title?.length ?? 0) > 200) {
          await _plugin.cancel(n.id);
          cleaned++;
        }
      }
      if (cleaned > 0) debugPrint('Limpas $cleaned notificações inválidas');
    } catch (e) {
      debugPrint('Erro no cleanup de notificações: $e');
    }
  }

  /// Cancela configs expiradas e renova a janela de agendamento quando necessário.
  static Future<void> performMaintenanceCleanup() async {
    try {
      await cleanupOldNotifications();

      final configs = await _loadRecurringConfigs();
      final now = DateTime.now();
      final toRemove = <String>[];
      final toRefill = <String, Map<String, dynamic>>{};

      for (final entry in configs.entries) {
        final config = entry.value as Map<String, dynamic>;

        final endDateStr = config['endDate'] as String?;
        if (endDateStr != null) {
          final endDate = DateTime.tryParse(endDateStr);
          if (endDate != null && now.isAfter(endDate)) {
            toRemove.add(entry.key);
            debugPrint('Config expirada: ${entry.key}');
            continue;
          }
        }

        // Renova janela se faltar menos de 7 dias para o fim do pré-agendamento
        final scheduledUntilStr = config['scheduledUntil'] as String?;
        if (scheduledUntilStr != null) {
          final scheduledUntil = DateTime.tryParse(scheduledUntilStr);
          if (scheduledUntil != null &&
              scheduledUntil.difference(now).inDays < 7) {
            toRefill[entry.key] = config;
          }
        }
      }

      // Cancela e remove configs expiradas
      if (toRemove.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
        final updated = jsonDecode(raw) as Map<String, dynamic>;
        for (final key in toRemove) {
          final config = configs[key] as Map<String, dynamic>?;
          if (config != null) {
            for (final id in (config['ids'] as List? ?? []).cast<int>()) {
              await _plugin.cancel(id);
            }
          }
          updated.remove(key);
        }
        await prefs.setString(_kRecurringConfigsKey, jsonEncode(updated));
        debugPrint('${toRemove.length} configs expiradas removidas');
      }

      // Renova janela de pré-agendamento
      for (final entry in toRefill.entries) {
        final config = entry.value;
        final s = _reminderSettingsFromConfig(config);
        if (s == null) continue;
        final notifTitle = config['notifTitle'] as String? ?? '🔔 Lembrete';
        final notifBody = config['notifBody'] as String? ?? '';
        await _refillRecurringAlarms(entry.key, notifTitle, notifBody, s);
      }
    } catch (e) {
      debugPrint('Erro no maintenance cleanup: $e');
    }
  }

  static Future<void> _refillRecurringAlarms(
    String annotationId,
    String notifTitle,
    String notifBody,
    ReminderSettings s,
  ) async {
    // NOVO: cancelar IDs antigos antes de gerar nova janela
    final configs = await _loadRecurringConfigs();
    final oldConfig = configs[annotationId] as Map<String, dynamic>?;
    if (oldConfig != null) {
      final oldIds = (oldConfig['ids'] as List? ?? []).cast<int>();
      for (final id in oldIds) {
        await _plugin.cancel(id);
      }
      debugPrint(
        'Refill: ${oldIds.length} IDs antigos cancelados antes do reagendamento',
      );
    }

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(android: _androidDetails);

    final now = DateTime.now();
    final occurrences = _computeOccurrences(s, now);
    final scheduledIds = <int>[];
    DateTime? scheduledUntil;

    for (final occ in occurrences) {
      final scheduledDate = tz.TZDateTime.from(occ.dateTime, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final key = 'recurring:$annotationId:${occ.dateTime.toIso8601String()}';
      final id = _stableId(key);

      try {
        await _plugin.zonedSchedule(
          id,
          '$notifTitle (${_formatTimeOfDay(occ.time)})',
          notifBody,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'annotation:$annotationId',
        );
        scheduledIds.add(id);
        if (scheduledUntil == null || occ.dateTime.isAfter(scheduledUntil)) {
          scheduledUntil = occ.dateTime;
        }
      } catch (e) {
        debugPrint('Falha ao reagendar ocorrência ${occ.dateTime}: $e');
      }
    }

    await _saveRecurringConfig(
      annotationId,
      scheduledIds,
      s.endDate,
      scheduledUntil,
      notifTitle,
      notifBody,
      s,
    );
    debugPrint('Refill: ${scheduledIds.length} ocorrências para $annotationId');
  }

  static Future<void> emergencyReset() async {
    try {
      debugPrint('EMERGENCY RESET: cancelando tudo');
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecurringConfigsKey);
      debugPrint('Emergency reset concluído');
    } catch (e) {
      debugPrint('Erro no emergency reset: $e');
    }
  }

  // ====== IDs estáveis (FNV-1a 32 bits) ======

  static int _stableId(String key) {
    const int fnvPrime = 16777619;
    const int fnvOffset = 2166136261;
    int hash = fnvOffset;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    if (hash > 0x7FFFFFFF) hash -= 0x100000000;
    return hash;
  }
}

// ====== Classe auxiliar interna ======

class _Occurrence {
  final DateTime dateTime;
  final TimeOfDay time;

  const _Occurrence(this.dateTime, this.time);
}
