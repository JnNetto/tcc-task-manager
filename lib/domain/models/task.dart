import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_status.dart';
import 'task_priority.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? sortOrder;
  final SyncStatus syncStatus;
  final DateTime? pendingSince;

  // Campos de notificacao (nao vao para Firestore necessariamente,
  // mas fazem parte do dominio local)
  final DateTime? reminderAt; // null se nao ha lembrete
  final bool isRecurring;
  final List<int> recurringHours; // horas do dia quando recorrente
  final List<int> recurringMinutes;
  final List<int> recurringWeekdays; // 1..7 (DateTime.monday..sunday)
  final DateTime? reminderEndDate;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder,
    this.syncStatus = SyncStatus.synced,
    this.pendingSince,
    this.reminderAt,
    this.isRecurring = false,
    this.recurringHours = const [],
    this.recurringMinutes = const [],
    this.recurringWeekdays = const [],
    this.reminderEndDate,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    SyncStatus? syncStatus,
    DateTime? pendingSince,
    DateTime? reminderAt,
    bool? isRecurring,
    List<int>? recurringHours,
    List<int>? recurringMinutes,
    List<int>? recurringWeekdays,
    DateTime? reminderEndDate,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingSince: pendingSince ?? this.pendingSince,
      reminderAt: reminderAt ?? this.reminderAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringHours: recurringHours ?? this.recurringHours,
      recurringMinutes: recurringMinutes ?? this.recurringMinutes,
      recurringWeekdays: recurringWeekdays ?? this.recurringWeekdays,
      reminderEndDate: reminderEndDate ?? this.reminderEndDate,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'priority': priority.index,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'sortOrder': sortOrder,
    'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
    'isRecurring': isRecurring,
    'recurringHours': recurringHours,
    'recurringMinutes': recurringMinutes,
    'recurringWeekdays': recurringWeekdays,
    'reminderEndDate': reminderEndDate != null
        ? Timestamp.fromDate(reminderEndDate!)
        : null,
  };

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw StateError('Documento Firestore sem dados: ${doc.id}');
    }
    final data = Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);

    DateTime readTs(Object? v, {required DateTime fallback}) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return fallback;
    }

    final now = DateTime.now();
    final created = readTs(data['createdAt'], fallback: now);
    final updated = readTs(data['updatedAt'], fallback: created);

    final pr = TaskPriority.values.length - 1;
    var pi = 1;
    final pRaw = data['priority'];
    if (pRaw is int) {
      pi = pRaw.clamp(0, pr);
    } else if (pRaw is num) {
      pi = pRaw.toInt().clamp(0, pr);
    }

    List<int> readIntList(Object? v) {
      if (v is! List) return const [];
      return v.map((e) {
        if (e is int) return e;
        if (e is num) return e.toInt();
        return 0;
      }).toList();
    }

    final title = data['title']?.toString() ?? '';

    return Task(
      id: doc.id,
      title: title,
      description: data['description']?.toString(),
      isCompleted: data['isCompleted'] == true,
      priority: TaskPriority.values[pi],
      createdAt: created,
      updatedAt: updated,
      sortOrder: (data['sortOrder'] is int)
          ? data['sortOrder'] as int
          : (data['sortOrder'] is num)
              ? (data['sortOrder'] as num).toInt()
              : null,
      syncStatus: SyncStatus.synced,
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      isRecurring: data['isRecurring'] == true,
      recurringHours: readIntList(data['recurringHours']),
      recurringMinutes: readIntList(data['recurringMinutes']),
      recurringWeekdays: readIntList(data['recurringWeekdays']),
      reminderEndDate: (data['reminderEndDate'] as Timestamp?)?.toDate(),
    );
  }
}
