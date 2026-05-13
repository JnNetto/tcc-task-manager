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
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      priority: TaskPriority.values[data['priority'] as int? ?? 1],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      sortOrder: data['sortOrder'] as int?,
      syncStatus: SyncStatus.synced,
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringHours: (data['recurringHours'] as List?)?.cast<int>() ?? const [],
      recurringMinutes:
          (data['recurringMinutes'] as List?)?.cast<int>() ?? const [],
      recurringWeekdays:
          (data['recurringWeekdays'] as List?)?.cast<int>() ?? const [],
      reminderEndDate: (data['reminderEndDate'] as Timestamp?)?.toDate(),
    );
  }
}
