import 'package:flutter/material.dart';

import '../domain/models/task.dart';
import '../domain/models/task_priority.dart';
import '../domain/models/sync_status.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onCompletedChanged;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onCompletedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);
    final relative = _relativeTime(task.createdAt);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: onCompletedChanged == null
              ? null
              : (value) => onCompletedChanged!(value ?? false),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: task.isCompleted
              ? theme.textTheme.titleMedium?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((task.description ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.priority.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Criada $relative',
                  style: theme.textTheme.bodySmall,
                ),
                if (task.syncStatus != SyncStatus.synced)
                  Icon(
                    Icons.sync_problem_rounded,
                    size: 18,
                    color: theme.colorScheme.tertiary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return const Color(0xFF2E7D32);
      case TaskPriority.medium:
        return const Color(0xFFEF6C00);
      case TaskPriority.high:
        return const Color(0xFFC62828);
    }
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'ha ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'ha ${diff.inHours} h';
    return 'ha ${diff.inDays} d';
  }
}
