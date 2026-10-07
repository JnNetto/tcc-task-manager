import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/task.dart';
import '../domain/models/task_priority.dart';

/// Serviço de lembretes alinhado ao padrão de `notifications_service.dart` na raiz
/// do repositório (permissões, canal, alarmes exactos, agendamento e manutenção).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static const _channelId = 'task_reminder_channel';
  static const _channelName = 'Lembretes de Tarefas';
  static const _channelDesc =
      'Notificacoes de lembretes para as suas tarefas';
  static const _engagementChannelId = 'engagement_reminder_channel';
  static const _engagementChannelName = 'Lembretes do estudo';
  static const _engagementChannelDesc =
      'Sugestoes para usar o app durante o periodo do estudo';
  static const _kRecurringConfigsKey = 'recurring_task_notifications';
  static const _kEngagementScheduledKey = 'engagement_reminders_scheduled_v1';
  static const _kDailyWindowDays = 30;
  static const _kEngagementCount = 14;
  static const _kEngagementIntervalDays = 2;
  static const _kEngagementHour = 10;
  static const _kEngagementMinute = 0;

  static const _engagementTitle = 'Lembrete amigável';

  /// Mensagens rotativas (uma por notificacao, 14 no total).
  static const _engagementBodies = [
    'Olá, que tal agendar uma tarefa?',
    'Lembre-se que anotar ajuda a lembrar!',
    'Que tal abrir o app e organizar o seu dia?',
    'Uma tarefa de cada vez — comece por uma pequena!',
    'O seu bloco de notas está à espera. Visite-o hoje!',
    'Registrar ideias agora poupa tempo depois.',
    'Já pensou no que precisa fazer hoje?',
    'Um minuto no app pode organizar a sua semana.',
    'Não deixe as tarefas na cabeça — anote-as aqui!',
    'Que tal rever as suas prioridades?',
    'Pequenos passos levam a grandes resultados. Anote um!',
    'O hábito de anotar começa com uma visita ao app.',
    'Tem algo pendente? Registe como tarefa!',
    'Voltar ao app mantém tudo sob controlo. Até já!',
  ];

  static bool _inited = false;

  static const _batteryChannel = MethodChannel('com.example.tcc_task_manager/battery');

  /// Solicita isenção de otimização de bateria (Doze mode) se ainda não concedida.
  /// Necessário para que o AlarmManager dispare no horário exato em Android 6+.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      final isExempt =
          await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
      if (!isExempt) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      debugPrint('Battery optimization check failed: $e');
    }
  }

  static Future<void> initialize() async {
    if (_inited) return;
    try {
      tz.initializeTimeZones();
      await _configureLocalTimeZone();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _engagementChannelId,
            _engagementChannelName,
            description: _engagementChannelDesc,
            importance: Importance.defaultImportance,
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
      debugPrint('Erro na inicializacao de notificacoes: $e');
      _inited = true;
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('Notificacao tocada: ${response.payload}');
  }

  /// O pacote `timezone` inicia [tz.local] em UTC. Sem isto, [TZDateTime.from]
  /// com horas escolhidas no telemóvel fica desalinhado e o AlarmManager pode
  /// nunca disparar (ou disparar na hora errada). O ficheiro na raiz do repo
  /// pode pertencer a outro projecto que já configurava o fuso doutra forma.
  static Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier.trim();
      if (id.isEmpty) return;
      tz.setLocalLocation(tz.getLocation(id));
      debugPrint('Fuso horario local: $id');
    } catch (e) {
      debugPrint(
        'Nao foi possivel aplicar fuso IANA (lembretes podem falhar): $e',
      );
    }
  }

  // ====== Permissões (igual ao exemplo notifications_service.dart) ======

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
      debugPrint('Erro ao solicitar permissao: $e');
      return false;
    }
  }

  /// Igual ao app **bloco_de_notas**: pede permissão de alarmes exactos quando o
  /// SO ainda não concedeu (pode abrir "Alarmes e lembretes"). Requer
  /// `SCHEDULE_EXACT_ALARM` no manifest; sem isso o modo inexact costuma falhar
  /// em Doze / fabricantes.
  static Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    // Antes do Android 12 (API 31) alarmes exatos são sempre permitidos.
    // SCHEDULE_EXACT_ALARM só existe a partir do API 31.
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdkInt < 31) return true;
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

  /// Android 13+: pede POST_NOTIFICATIONS. Útil após [runApp] (ver `main.dart`).
  static Future<void> requestAndroidPostNotificationsPermission() async {
    await initialize();
    await _ensureNotificationsPermission();
  }

  // ====== Lembretes de engajamento (primeira identificação no dispositivo) ======

  /// Agenda [_kEngagementCount] notificações locais, espaçadas de
  /// [_kEngagementIntervalDays] dias, na primeira vez que o participante
  /// conclui o onboarding neste dispositivo. Idempotente via SharedPreferences.
  static Future<void> scheduleEngagementRemindersIfNeeded() async {
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kEngagementScheduledKey) == true) {
      return;
    }

    final hasNotifPerm = await _ensureNotificationsPermission();
    if (!hasNotifPerm) {
      debugPrint(
        'POST_NOTIFICATIONS negada. Lembretes de engajamento nao agendados.',
      );
      return;
    }

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(android: _engagementAndroidDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;

    for (var i = 0; i < _kEngagementCount; i++) {
      final dayOffset = (i + 1) * _kEngagementIntervalDays;
      final targetDay = now.add(Duration(days: dayOffset));
      final scheduledDate = tz.TZDateTime(
        tz.local,
        targetDay.year,
        targetDay.month,
        targetDay.day,
        _kEngagementHour,
        _kEngagementMinute,
      );
      if (scheduledDate.isBefore(now)) continue;

      final body = _engagementBodies[i % _engagementBodies.length];
      final id = _stableId('engagement:$i');

      try {
        await _plugin.zonedSchedule(
          id,
          _engagementTitle,
          body,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'engagement:$i',
        );
        scheduled++;
        debugPrint('Lembrete de engajamento $i em $scheduledDate');
      } catch (e) {
        debugPrint('Falha ao agendar lembrete de engajamento $i: $e');
      }
    }

    if (scheduled > 0) {
      await prefs.setBool(_kEngagementScheduledKey, true);
      debugPrint('$scheduled lembretes de engajamento agendados');
    }
  }

  // ====== API principal (espelha scheduleNotificationForAnnotation) ======

  static Future<void> scheduleForTask(Task task) async {
    await initialize();

    final wantsReminder = task.reminderAt != null || task.isRecurring;
    if (!wantsReminder) {
      await cancelForTask(task.id);
      return;
    }

    final hasNotifPerm = await _ensureNotificationsPermission();
    if (!hasNotifPerm) {
      debugPrint('POST_NOTIFICATIONS negada. Notificacao nao agendada.');
      return;
    }

    final notifEnabled = await _areNotificationsEnabled();
    if (!notifEnabled) {
      debugPrint('Canal de notificacoes desativado pelo utilizador.');
    }

    await cancelForTask(task.id);

    if (!task.isRecurring) {
      await _scheduleSingle(task);
    } else {
      await _scheduleRecurring(task);
    }
  }

  static Future<void> rescheduleForTask(Task task) => scheduleForTask(task);

  static Future<void> cancelForTask(String taskId) async {
    await _plugin.cancel(_stableId('single:$taskId'));

    final configs = await _loadRecurringConfigs();
    final config = configs[taskId] as Map<String, dynamic>?;
    if (config != null) {
      final ids = (config['ids'] as List? ?? []).cast<int>();
      for (final id in ids) {
        await _plugin.cancel(id);
      }
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      final targetPayload = 'task:$taskId';
      var orphanCount = 0;
      for (final p in pending) {
        if (p.payload == targetPayload) {
          await _plugin.cancel(p.id);
          orphanCount++;
        }
      }
      if (orphanCount > 0) {
        debugPrint(
          'Canceladas $orphanCount notificacoes orfas de $taskId',
        );
      }
    } catch (e) {
      debugPrint('Erro ao varrer notificacoes orfas: $e');
    }

    await _removeRecurringConfig(taskId);
    debugPrint('Notificacoes canceladas para $taskId');
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  // ====== Lembrete único ======

  static Future<void> _scheduleSingle(Task task) async {
    final reminderAt = task.reminderAt;
    if (reminderAt == null) return;

    final scheduledDate = tz.TZDateTime.from(reminderAt, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final canExact = await _canScheduleExactAlarms();
    final notificationData = _getNotificationContent(task);
    const details = NotificationDetails(android: _androidDetails);
    final id = _stableId('single:${task.id}');

    // Tenta exato; se o dispositivo bloquear (ex.: OEM com bateria restritiva),
    // cai para inexato antes de propagar o erro.
    final modes = [
      if (canExact) AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    Object? lastError;
    StackTrace? lastStack;
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id,
          notificationData['title'],
          notificationData['body'],
          scheduledDate,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:${task.id}',
        );
        debugPrint('Notificacao unica agendada: ${task.id} em $scheduledDate ($mode)');
        return;
      } catch (e, st) {
        debugPrint('=== NOTIF ERROR ($mode) ===\n$e\n$st\n=== END ===');
        lastError = e;
        lastStack = st;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  // ====== Recorrentes (pré-agenda na janela, como o exemplo) ======

  static Future<void> _scheduleRecurring(Task task) async {
    if (task.recurringHours.isEmpty ||
        task.recurringMinutes.isEmpty ||
        task.recurringHours.length != task.recurringMinutes.length) {
      return;
    }

    final now = DateTime.now();
    final end = task.reminderEndDate;
    if (end != null && now.isAfter(end)) {
      debugPrint(
        'Recorrencia encerrada para ${task.id} — passou do endDate',
      );
      return;
    }

    final existingConfigs = await _loadRecurringConfigs();
    final oldConfig = existingConfigs[task.id] as Map<String, dynamic>?;
    if (oldConfig != null) {
      final oldIds = (oldConfig['ids'] as List? ?? []).cast<int>();
      for (final id in oldIds) {
        await _plugin.cancel(id);
      }
    }

    final notifData = _getNotificationContent(task);
    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(android: _androidDetails);
    final occurrences = _computeOccurrences(task, now);
    final scheduledIds = <int>[];
    DateTime? scheduledUntil;

    for (final occ in occurrences) {
      final scheduledDate = tz.TZDateTime.from(occ, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final key = 'recurring:${task.id}:${occ.toIso8601String()}';
      final id = _stableId(key);

      try {
        await _plugin.zonedSchedule(
          id,
          '${notifData['title']} (${_formatHm(occ)})',
          notifData['body']!,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:${task.id}',
        );
        scheduledIds.add(id);
        if (scheduledUntil == null || occ.isAfter(scheduledUntil)) {
          scheduledUntil = occ;
        }
        debugPrint('Agendado: ${task.id} em $occ');
      } catch (e) {
        debugPrint('Falha ao agendar ocorrencia $occ: $e');
      }
    }

    await _saveRecurringConfig(
      taskId: task.id,
      notifIds: scheduledIds,
      endDate: task.reminderEndDate,
      scheduledUntil: scheduledUntil,
      notifTitle: notifData['title']!,
      notifBody: notifData['body']!,
      recurringHours: task.recurringHours,
      recurringMinutes: task.recurringMinutes,
      recurringWeekdays: task.recurringWeekdays,
    );
    debugPrint(
      '${scheduledIds.length} ocorrencias agendadas para ${task.id}',
    );
  }

  static String _formatHm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static List<DateTime> _computeOccurrences(Task t, DateTime from) {
    final result = <DateTime>[];
    if (!t.isRecurring) {
      if (t.reminderAt != null && t.reminderAt!.isAfter(from)) {
        result.add(t.reminderAt!);
      }
      return result;
    }

    if (t.recurringHours.length != t.recurringMinutes.length) return result;

    final endDate = t.reminderEndDate;
    final weekdays = t.recurringWeekdays.isEmpty
        ? const <int>{1, 2, 3, 4, 5, 6, 7}
        : t.recurringWeekdays.toSet();
    for (int offset = 0; offset < _kDailyWindowDays; offset++) {
      final date = from.add(Duration(days: offset));
      if (!weekdays.contains(date.weekday)) continue;
      for (int i = 0; i < t.recurringHours.length; i++) {
        final dt = DateTime(
          date.year,
          date.month,
          date.day,
          t.recurringHours[i],
          t.recurringMinutes[i],
        );
        if (dt.isAfter(from) && (endDate == null || !dt.isAfter(endDate))) {
          result.add(dt);
        }
      }
    }
    return result;
  }

  // ====== Limpeza / manutenção (como o exemplo) ======

  static Future<void> cleanupOldNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      var cleaned = 0;
      for (final n in pending) {
        if (n.title == null ||
            n.title!.isEmpty ||
            (n.title?.length ?? 0) > 200) {
          await _plugin.cancel(n.id);
          cleaned++;
        }
      }
      if (cleaned > 0) debugPrint('Limpas $cleaned notificacoes invalidas');
    } catch (e) {
      debugPrint('Erro no cleanup de notificacoes: $e');
    }
  }

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

        final scheduledUntilStr = config['scheduledUntil'] as String?;
        if (scheduledUntilStr != null) {
          final scheduledUntil = DateTime.tryParse(scheduledUntilStr);
          if (scheduledUntil != null &&
              scheduledUntil.difference(now).inDays < 7) {
            toRefill[entry.key] = config;
          }
        }
      }

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

      for (final entry in toRefill.entries) {
        await _refillRecurringForTask(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('Erro no maintenance cleanup: $e');
    }
  }

  static Future<void> _refillRecurringForTask(
    String taskId,
    Map<String, dynamic> config,
  ) async {
    final task = _taskFromConfig(taskId, config);
    if (task == null) return;

    final configs = await _loadRecurringConfigs();
    final oldConfig = configs[taskId] as Map<String, dynamic>?;
    if (oldConfig != null) {
      final oldIds = (oldConfig['ids'] as List? ?? []).cast<int>();
      for (final id in oldIds) {
        await _plugin.cancel(id);
      }
      debugPrint(
        'Refill: ${oldIds.length} IDs antigos cancelados antes do reagendamento',
      );
    }

    final notifTitle = config['notifTitle'] as String? ?? 'Lembrete de tarefa';
    final notifBody = config['notifBody'] as String? ?? '';
    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(android: _androidDetails);

    final now = DateTime.now();
    final occurrences = _computeOccurrences(task, now);
    final scheduledIds = <int>[];
    DateTime? scheduledUntil;

    for (final occ in occurrences) {
      final scheduledDate = tz.TZDateTime.from(occ, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final key = 'recurring:$taskId:${occ.toIso8601String()}';
      final id = _stableId(key);

      try {
        await _plugin.zonedSchedule(
          id,
          '$notifTitle (${_formatHm(occ)})',
          notifBody,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:$taskId',
        );
        scheduledIds.add(id);
        if (scheduledUntil == null || occ.isAfter(scheduledUntil)) {
          scheduledUntil = occ;
        }
      } catch (e) {
        debugPrint('Falha ao reagendar ocorrencia $occ: $e');
      }
    }

    await _saveRecurringConfig(
      taskId: taskId,
      notifIds: scheduledIds,
      endDate: task.reminderEndDate,
      scheduledUntil: scheduledUntil,
      notifTitle: notifTitle,
      notifBody: notifBody,
      recurringHours: task.recurringHours,
      recurringMinutes: task.recurringMinutes,
      recurringWeekdays: task.recurringWeekdays,
    );
    debugPrint('Refill: ${scheduledIds.length} ocorrencias para $taskId');
  }

  static Task? _taskFromConfig(String taskId, Map<String, dynamic> config) {
    try {
      final hours = (config['recurringHours'] as List? ?? []).cast<int>();
      final minutes = (config['recurringMinutes'] as List? ?? []).cast<int>();
      final weekdays = (config['recurringWeekdays'] as List? ?? []).cast<int>();
      final endDateStr = config['endDate'] as String?;
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      return Task(
        id: taskId,
        title: (config['taskTitle'] as String?) ?? 'Tarefa',
        description: config['taskDescription'] as String?,
        isCompleted: false,
        priority: TaskPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isRecurring: true,
        recurringHours: hours,
        recurringMinutes: minutes,
        recurringWeekdays: weekdays,
        reminderEndDate: endDate,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveRecurringConfig({
    required String taskId,
    required List<int> notifIds,
    required DateTime? endDate,
    required DateTime? scheduledUntil,
    required String notifTitle,
    required String notifBody,
    required List<int> recurringHours,
    required List<int> recurringMinutes,
    required List<int> recurringWeekdays,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
      final configs = jsonDecode(raw) as Map<String, dynamic>;
      configs[taskId] = {
        'ids': notifIds,
        'endDate': endDate?.toIso8601String(),
        'scheduledUntil': scheduledUntil?.toIso8601String(),
        'notifTitle': notifTitle,
        'notifBody': notifBody,
        'recurringHours': recurringHours,
        'recurringMinutes': recurringMinutes,
        'recurringWeekdays': recurringWeekdays,
        'taskTitle': notifTitle,
        'taskDescription': notifBody,
      };
      await prefs.setString(_kRecurringConfigsKey, jsonEncode(configs));
    } catch (e) {
      debugPrint('Erro ao salvar config recorrente: $e');
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

  static Future<void> _removeRecurringConfig(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
      final configs = jsonDecode(raw) as Map<String, dynamic>;
      configs.remove(taskId);
      await prefs.setString(_kRecurringConfigsKey, jsonEncode(configs));
    } catch (e) {
      debugPrint('Erro ao remover config recorrente: $e');
    }
  }

  static Map<String, String> _getNotificationContent(Task task) {
    final title = task.title.trim().isEmpty ? 'Lembrete de tarefa' : task.title;
    final description = (task.description ?? '').trim();
    final body =
        description.isEmpty ? 'Tem uma tarefa pendente.' : description;
    return {'title': title, 'body': body};
  }

  static int _stableId(String key) {
    const int fnvPrime = 16777619;
    const int fnvOffset = 2166136261;
    var hash = fnvOffset;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    if (hash > 0x7FFFFFFF) hash -= 0x100000000;
    return hash;
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
  );

  static const _engagementAndroidDetails = AndroidNotificationDetails(
    _engagementChannelId,
    _engagementChannelName,
    channelDescription: _engagementChannelDesc,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );
}
