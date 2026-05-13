import 'package:hive/hive.dart';

import '../../domain/models/sync_status.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_priority.dart';

part 'task_hive_model.g.dart';

@HiveType(typeId: 0)
class TaskHiveModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String? description;
  @HiveField(3)
  bool isCompleted;
  @HiveField(4)
  int priority;
  @HiveField(5)
  DateTime createdAt;
  @HiveField(6)
  DateTime updatedAt;
  @HiveField(15)
  int? sortOrder;
  @HiveField(7)
  int syncStatus;
  @HiveField(8)
  DateTime? pendingSince;
  @HiveField(9)
  DateTime? reminderAt;
  @HiveField(10)
  bool isRecurring;
  @HiveField(11)
  List<int> recurringHours;
  @HiveField(12)
  List<int> recurringMinutes;
  @HiveField(13)
  DateTime? reminderEndDate;
  @HiveField(14)
  List<int> recurringWeekdays;

  TaskHiveModel({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder,
    required this.syncStatus,
    this.pendingSince,
    this.reminderAt,
    this.isRecurring = false,
    this.recurringHours = const [],
    this.recurringMinutes = const [],
    this.reminderEndDate,
    this.recurringWeekdays = const [],
  });

  factory TaskHiveModel.fromDomain(Task t) => TaskHiveModel(
    id: t.id,
    title: t.title,
    description: t.description,
    isCompleted: t.isCompleted,
    priority: t.priority.index,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    sortOrder: t.sortOrder,
    syncStatus: t.syncStatus.index,
    pendingSince: t.pendingSince,
    reminderAt: t.reminderAt,
    isRecurring: t.isRecurring,
    recurringHours: t.recurringHours,
    recurringMinutes: t.recurringMinutes,
    reminderEndDate: t.reminderEndDate,
    recurringWeekdays: t.recurringWeekdays,
  );

  Task toDomain() => Task(
    id: id,
    title: title,
    description: description,
    isCompleted: isCompleted,
    priority: TaskPriority.values[priority],
    createdAt: createdAt,
    updatedAt: updatedAt,
    sortOrder: sortOrder,
    syncStatus: SyncStatus.values[syncStatus],
    pendingSince: pendingSince,
    reminderAt: reminderAt,
    isRecurring: isRecurring,
    recurringHours: recurringHours,
    recurringMinutes: recurringMinutes,
    recurringWeekdays: recurringWeekdays,
    reminderEndDate: reminderEndDate,
  );
}
