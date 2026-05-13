import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/task.dart';
import '../domain/models/task_priority.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'task_reminder_channel';
  static const _channelName = 'Lembretes de Tarefas';
  static const _channelDesc = 'Notificacoes de lembretes para suas tarefas';
  static const _kRecurringConfigsKey = 'recurring_task_notifications';
  static const _kDailyWindowDays = 30;

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
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notificacao tocada: ${response.payload}');
        },
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
          ),
        );
        await android.requestNotificationsPermission();
      }

      _inited = true;
      await performMaintenanceCleanup();
    } catch (e) {
      debugPrint('Erro init notificacoes: $e');
      _inited = true;
    }
  }

  static Future<void> scheduleForTask(Task task) async {
    await initialize();
    await cancelForTask(task.id);

    if (!task.isRecurring && task.reminderAt == null) return;

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
      for (final p in pending) {
        if (p.payload == targetPayload) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('Erro varredura orfas: $e');
    }

    await _removeRecurringConfig(taskId);
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() {
    return _plugin.pendingNotificationRequests();
  }

  static Future<void> _scheduleSingle(Task task) async {
    final reminderAt = task.reminderAt;
    if (reminderAt == null) return;

    final scheduledDate = tz.TZDateTime.from(reminderAt, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final content = _getNotificationContent(task);
    final id = _stableId('single:${task.id}');
    await _plugin.zonedSchedule(
      id,
      content['title'],
      content['body'],
      scheduledDate,
      const NotificationDetails(android: _androidDetails),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:${task.id}',
    );
  }

  static Future<void> _scheduleRecurring(Task task) async {
    if (task.recurringHours.isEmpty ||
        task.recurringMinutes.isEmpty ||
        task.recurringHours.length != task.recurringMinutes.length) {
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

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = DateTime.now();
    final occurrences = _computeOccurrences(task, now);
    final content = _getNotificationContent(task);
    final scheduledIds = <int>[];
    DateTime? scheduledUntil;

    for (final occ in occurrences) {
      final scheduledDate = tz.TZDateTime.from(occ, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final id = _stableId('recurring:${task.id}:${occ.toIso8601String()}');
      await _plugin.zonedSchedule(
        id,
        content['title'],
        content['body'],
        scheduledDate,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:${task.id}',
      );
      scheduledIds.add(id);
      if (scheduledUntil == null || occ.isAfter(scheduledUntil)) {
        scheduledUntil = occ;
      }
    }

    await _saveRecurringConfig(
      taskId: task.id,
      notifIds: scheduledIds,
      endDate: task.reminderEndDate,
      scheduledUntil: scheduledUntil,
      notifTitle: content['title']!,
      notifBody: content['body']!,
      recurringHours: task.recurringHours,
      recurringMinutes: task.recurringMinutes,
      recurringWeekdays: task.recurringWeekdays,
    );
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

  static Future<void> performMaintenanceCleanup() async {
    try {
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
            continue;
          }
        }

        final scheduledUntilStr = config['scheduledUntil'] as String?;
        if (scheduledUntilStr != null) {
          final scheduledUntil = DateTime.tryParse(scheduledUntilStr);
          if (scheduledUntil != null && scheduledUntil.difference(now).inDays < 7) {
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
      }

      for (final entry in toRefill.entries) {
        final task = _taskFromConfig(entry.key, entry.value);
        if (task == null) continue;
        await _scheduleRecurring(task);
      }
    } catch (e) {
      debugPrint('Erro maintenance cleanup: $e');
    }
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
  }

  static Future<Map<String, dynamic>> _loadRecurringConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> _removeRecurringConfig(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecurringConfigsKey) ?? '{}';
    final configs = jsonDecode(raw) as Map<String, dynamic>;
    configs.remove(taskId);
    await prefs.setString(_kRecurringConfigsKey, jsonEncode(configs));
  }

  static Map<String, String> _getNotificationContent(Task task) {
    final title = task.title.trim().isEmpty ? 'Lembrete de tarefa' : task.title;
    final description = (task.description ?? '').trim();
    final body = description.isEmpty ? 'Voce tem uma tarefa pendente.' : description;
    return {'title': title, 'body': body};
  }

  static Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
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
}
