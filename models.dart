// ignore_for_file: unnecessary_brace_in_string_interps, use_super_parameters

import 'package:flutter/material.dart';

// Models
export 'calendar_event.dart';

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
}

// ADICIONE estas validações e melhorias ao seu modelo ReminderSettings:

class ReminderSettings {
  final RecurrenceType recurrenceType;
  final List<TimeOfDay> dailyTimes;
  final DateTime? endDate;
  final Set<int> weekdays; // 1=Segunda, 7=Domingo
  final int? monthDay; // 1-31

  const ReminderSettings({
    this.recurrenceType = RecurrenceType.none,
    this.dailyTimes = const [],
    this.endDate,
    this.weekdays = const {},
    this.monthDay,
  });

  // NOVO: Validação dos dados
  bool get isValid {
    if (recurrenceType == RecurrenceType.none) return true;
    if (dailyTimes.isEmpty) return false;

    switch (recurrenceType) {
      case RecurrenceType.weekly:
        return weekdays.isNotEmpty &&
            weekdays.every((day) => day >= 1 && day <= 7);
      case RecurrenceType.monthly:
        return monthDay != null && monthDay! >= 1 && monthDay! <= 31;
      case RecurrenceType.daily:
        return true;
      default:
        return false;
    }
  }

  // NOVO: Método para obter descrição legível
  String get description {
    switch (recurrenceType) {
      case RecurrenceType.daily:
        return 'Diário às ${dailyTimes.map((t) => _formatTime(t)).join(', ')}';
      case RecurrenceType.weekly:
        final days = weekdays.map((day) => _getWeekdayName(day)).join(', ');
        return 'Semanal ($days) às ${dailyTimes.map((t) => _formatTime(t)).join(', ')}';
      case RecurrenceType.monthly:
        return 'Mensal (dia ${monthDay}) às ${dailyTimes.map((t) => _formatTime(t)).join(', ')}';
      case RecurrenceType.none:
      default:
        return 'Lembrete único';
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getWeekdayName(int weekday) {
    const names = {
      1: 'Seg',
      2: 'Ter',
      3: 'Qua',
      4: 'Qui',
      5: 'Sex',
      6: 'Sáb',
      7: 'Dom'
    };
    return names[weekday] ?? '';
  }

  ReminderSettings copyWith({
    RecurrenceType? recurrenceType,
    List<TimeOfDay>? dailyTimes,
    DateTime? endDate,
    Set<int>? weekdays,
    int? monthDay,
  }) {
    return ReminderSettings(
      recurrenceType: recurrenceType ?? this.recurrenceType,
      dailyTimes: dailyTimes ?? this.dailyTimes,
      endDate: endDate ?? this.endDate,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
    );
  }

  // NOVO: Métodos para serialização/deserialização se necessário
  Map<String, dynamic> toJson() {
    return {
      'recurrenceType': recurrenceType.toString(),
      'dailyTimes':
          dailyTimes.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
      'endDate': endDate?.toIso8601String(),
      'weekdays': weekdays.toList(),
      'monthDay': monthDay,
    };
  }

  static ReminderSettings fromJson(Map<String, dynamic> json) {
    final recurrenceType = RecurrenceType.values.firstWhere(
      (e) => e.toString() == json['recurrenceType'],
      orElse: () => RecurrenceType.none,
    );

    final dailyTimes = (json['dailyTimes'] as List?)
            ?.map((t) => TimeOfDay(hour: t['hour'], minute: t['minute']))
            .toList() ??
        [];

    final endDate =
        json['endDate'] != null ? DateTime.parse(json['endDate']) : null;

    final weekdays =
        (json['weekdays'] as List?)?.cast<int>().toSet() ?? <int>{};
    final monthDay = json['monthDay'] as int?;

    return ReminderSettings(
      recurrenceType: recurrenceType,
      dailyTimes: dailyTimes,
      endDate: endDate,
      weekdays: weekdays,
      monthDay: monthDay,
    );
  }
}

class NoteCard {
  String id;
  String title;
  List<Annotation> annotations;

  NoteCard({required this.id, required this.title, required this.annotations});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'annotations': annotations.map((a) => a.toJson()).toList(),
    };
  }

  factory NoteCard.fromJson(Map<String, dynamic> json) {
    List<Annotation> annotations = [];
    if (json['annotations'] != null) {
      for (var annotationJson in json['annotations']) {
        switch (annotationJson['type']) {
          case 'text':
            annotations.add(TextAnnotation.fromJson(annotationJson));
            break;
          case 'checklist':
            annotations.add(ChecklistAnnotation.fromJson(annotationJson));
            break;
          case 'file':
            annotations.add(FileAnnotation.fromJson(annotationJson));
            break;
        }
      }
    }
    return NoteCard(
      id: json['id'],
      title: json['title'],
      annotations: annotations,
    );
  }
}

abstract class Annotation {
  String id;
  String type;
  DateTime? alarmDateTime;
  ReminderSettings reminderSettings;

  Annotation({
    required this.id,
    required this.type,
    this.alarmDateTime,
    ReminderSettings? reminderSettings,
  }) : reminderSettings = reminderSettings ?? const ReminderSettings();

  Map<String, dynamic> toJson();
}

class TextAnnotation extends Annotation {
  String content;

  TextAnnotation({
    required String id,
    required this.content,
    DateTime? alarmDateTime,
    ReminderSettings? reminderSettings,
  }) : super(
            id: id,
            type: 'text',
            alarmDateTime: alarmDateTime,
            reminderSettings: reminderSettings);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'alarmDateTime': alarmDateTime?.toIso8601String(),
      'reminderSettings': reminderSettings.toJson(),
    };
  }

  factory TextAnnotation.fromJson(Map<String, dynamic> json) {
    return TextAnnotation(
      id: json['id'],
      content: json['content'],
      alarmDateTime: json['alarmDateTime'] != null
          ? DateTime.parse(json['alarmDateTime'])
          : null,
      reminderSettings: json['reminderSettings'] != null
          ? ReminderSettings.fromJson(json['reminderSettings'])
          : const ReminderSettings(),
    );
  }
}

class ChecklistAnnotation extends Annotation {
  String title;
  List<ChecklistItem> items;

  ChecklistAnnotation({
    required String id,
    required this.title,
    required this.items,
    DateTime? alarmDateTime,
    ReminderSettings? reminderSettings,
  }) : super(
            id: id,
            type: 'checklist',
            alarmDateTime: alarmDateTime,
            reminderSettings: reminderSettings);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
      'alarmDateTime': alarmDateTime?.toIso8601String(),
      'reminderSettings': reminderSettings.toJson(),
    };
  }

  factory ChecklistAnnotation.fromJson(Map<String, dynamic> json) {
    List<ChecklistItem> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => ChecklistItem.fromJson(item))
          .toList();
    }
    return ChecklistAnnotation(
      id: json['id'],
      title: json['title'],
      items: items,
      alarmDateTime: json['alarmDateTime'] != null
          ? DateTime.parse(json['alarmDateTime'])
          : null,
      reminderSettings: json['reminderSettings'] != null
          ? ReminderSettings.fromJson(json['reminderSettings'])
          : const ReminderSettings(),
    );
  }
}

class FileAnnotation extends Annotation {
  String fileName;
  String filePath;
  String fileType;
  String mimeType;
  String? displayName; // Nome personalizado para exibição

  FileAnnotation({
    required String id,
    required this.fileName,
    required this.filePath,
    this.fileType = 'file',
    this.mimeType = 'unknown',
    this.displayName,
    DateTime? alarmDateTime,
    ReminderSettings? reminderSettings,
  }) : super(
            id: id,
            type: 'file',
            alarmDateTime: alarmDateTime,
            reminderSettings: reminderSettings);

  // Getter para o nome de exibição
  String get displayFileName => displayName ?? fileName;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'fileName': fileName,
      'filePath': filePath,
      'fileType': fileType,
      'mimeType': mimeType,
      'displayName': displayName,
      'alarmDateTime': alarmDateTime?.toIso8601String(),
      'reminderSettings': reminderSettings.toJson(),
    };
  }

  factory FileAnnotation.fromJson(Map<String, dynamic> json) {
    return FileAnnotation(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      fileType: json['fileType'] ?? 'file',
      mimeType: json['mimeType'] ?? 'unknown',
      displayName: json['displayName'],
      alarmDateTime: json['alarmDateTime'] != null
          ? DateTime.parse(json['alarmDateTime'])
          : null,
      reminderSettings: json['reminderSettings'] != null
          ? ReminderSettings.fromJson(json['reminderSettings'])
          : const ReminderSettings(),
    );
  }
}

class ChecklistItem {
  String text;
  bool isChecked;

  ChecklistItem({required this.text, required this.isChecked});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isChecked': isChecked,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      text: json['text'],
      isChecked: json['isChecked'] ?? false,
    );
  }
}

// Enum para tipos de prioridade do pop-up
enum PopupPriority {
  low,
  medium,
  high,
  urgent,
}

// Enum para status do pop-up
enum PopupStatus {
  scheduled,
  displayed,
  dismissed,
  completed,
}

// Modelo para Pop-ups
class PopupReminder {
  String id;
  String title;
  String? message;
  DateTime scheduledDateTime;
  PopupPriority priority;
  PopupStatus status;
  DateTime createdAt;
  DateTime? displayedAt;
  DateTime? completedAt;
  int snoozeCount;
  Duration? snoozeDuration;
  bool isRecurring;
  ReminderSettings? recurringSettings;
  Map<String, dynamic>? customData;

  PopupReminder({
    required this.id,
    required this.title,
    this.message,
    required this.scheduledDateTime,
    this.priority = PopupPriority.medium,
    this.status = PopupStatus.scheduled,
    DateTime? createdAt,
    this.displayedAt,
    this.completedAt,
    this.snoozeCount = 0,
    this.snoozeDuration,
    this.isRecurring = false,
    this.recurringSettings,
    this.customData,
  }) : createdAt = createdAt ?? DateTime.now();

  // Getters auxiliares
  bool get isActive => status == PopupStatus.scheduled;
  bool get isCompleted => status == PopupStatus.completed;
  bool get isDue => DateTime.now().isAfter(scheduledDateTime) && isActive;
  
  String get priorityName {
    switch (priority) {
      case PopupPriority.low:
        return 'Baixa';
      case PopupPriority.medium:
        return 'Média';
      case PopupPriority.high:
        return 'Alta';
      case PopupPriority.urgent:
        return 'Urgente';
    }
  }
  
  Color get priorityColor {
    switch (priority) {
      case PopupPriority.low:
        return Colors.green;
      case PopupPriority.medium:
        return Colors.blue;
      case PopupPriority.high:
        return Colors.orange;
      case PopupPriority.urgent:
        return Colors.red;
    }
  }

  String get statusName {
    switch (status) {
      case PopupStatus.scheduled:
        return 'Agendado';
      case PopupStatus.displayed:
        return 'Exibido';
      case PopupStatus.dismissed:
        return 'Dispensado';
      case PopupStatus.completed:
        return 'Concluído';
    }
  }

  // Métodos para atualizar status
  void markAsDisplayed() {
    status = PopupStatus.displayed;
    displayedAt = DateTime.now();
  }

  void markAsCompleted() {
    status = PopupStatus.completed;
    completedAt = DateTime.now();
  }

  void markAsDismissed() {
    status = PopupStatus.dismissed;
  }


  // Serialização
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'priority': priority.toString(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'displayedAt': displayedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'snoozeCount': snoozeCount,
      'snoozeDuration': snoozeDuration?.inMinutes,
      'isRecurring': isRecurring,
      'recurringSettings': recurringSettings?.toJson(),
      'customData': customData,
    };
  }

  factory PopupReminder.fromJson(Map<String, dynamic> json) {
    return PopupReminder(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      scheduledDateTime: DateTime.parse(json['scheduledDateTime']),
      priority: PopupPriority.values.firstWhere(
        (e) => e.toString() == json['priority'],
        orElse: () => PopupPriority.medium,
      ),
      status: PopupStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => PopupStatus.scheduled,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      displayedAt: json['displayedAt'] != null 
          ? DateTime.parse(json['displayedAt']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      snoozeCount: json['snoozeCount'] ?? 0,
      snoozeDuration: json['snoozeDuration'] != null 
          ? Duration(minutes: json['snoozeDuration']) 
          : null,
      isRecurring: json['isRecurring'] ?? false,
      recurringSettings: json['recurringSettings'] != null
          ? ReminderSettings.fromJson(json['recurringSettings'])
          : null,
      customData: json['customData'],
    );
  }

  PopupReminder copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? scheduledDateTime,
    PopupPriority? priority,
    PopupStatus? status,
    DateTime? createdAt,
    DateTime? displayedAt,
    DateTime? completedAt,
    int? snoozeCount,
    Duration? snoozeDuration,
    bool? isRecurring,
    ReminderSettings? recurringSettings,
    Map<String, dynamic>? customData,
  }) {
    return PopupReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      displayedAt: displayedAt ?? this.displayedAt,
      completedAt: completedAt ?? this.completedAt,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringSettings: recurringSettings ?? this.recurringSettings,
      customData: customData ?? this.customData,
    );
  }
}
