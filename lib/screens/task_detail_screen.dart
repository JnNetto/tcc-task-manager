import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models/task.dart';
import '../domain/models/task_priority.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/common/error_dialog.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return _TaskDetailView(task: task);
  }
}

class _TaskDetailView extends StatefulWidget {
  final Task task;
  const _TaskDetailView({required this.task});

  @override
  State<_TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<_TaskDetailView> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da tarefa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(task.description ?? 'Sem descricao'),
          const SizedBox(height: 16),
          Text('Concluida: ${task.isCompleted ? "Sim" : "Nao"}'),
          Text('Prioridade: ${task.priority.label}'),
          Text('Criada em: ${task.createdAt}'),
          Text('Atualizada em: ${task.updatedAt}'),
          Text('Recorrente: ${task.isRecurring ? "Sim" : "Nao"}'),
          if (task.reminderAt != null) Text('Lembrete unico: ${task.reminderAt}'),
          if (task.isRecurring) ...[
            const SizedBox(height: 8),
            Text('Dias: ${_weekdayLabel(task.recurringWeekdays)}'),
            const Text('Horarios recorrentes:'),
            ...task.recurringHours.asMap().entries.map(
              (entry) => Text(
                '- ${entry.value.toString().padLeft(2, '0')}:${task.recurringMinutes[entry.key].toString().padLeft(2, '0')}',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () async => _toggleCompleted(context),
            child: Text(task.isCompleted ? 'Reabrir tarefa' : 'Concluir tarefa'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _deleting ? null : () async => _confirmDelete(context),
            child: _deleting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(List<int> weekdays) {
    final map = {
      1: 'Seg',
      2: 'Ter',
      3: 'Qua',
      4: 'Qui',
      5: 'Sex',
      6: 'Sab',
      7: 'Dom',
    };
    final list = weekdays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : weekdays;
    return list.map((d) => map[d] ?? d.toString()).join(', ');
  }

  Future<void> _toggleCompleted(BuildContext context) async {
    final task = widget.task;
    final repo = context.read<TaskProvider>();
    final navigator = Navigator.of(context);
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now(),
    );

    Future<void> action() async {
      await repo.updateTask(updated);
      if (updated.isCompleted) {
        await NotificationService.cancelForTask(updated.id);
      } else if (updated.reminderAt != null || updated.isRecurring) {
        await NotificationService.scheduleForTask(updated);
      }
    }

    try {
      await action();
      if (context.mounted) navigator.pop();
    } catch (e) {
      if (!context.mounted) return;
      await _handleError(context, operation: 'update', action: action, error: e);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (_deleting) return;
    final task = widget.task;
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: const Text('Deseja excluir esta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final repo = context.read<TaskProvider>();
    Future<void> action() async {
      await NotificationService.cancelForTask(task.id);
      await repo.deleteTask(task.id);
    }

    try {
      if (mounted) setState(() => _deleting = true);
      await action();
      if (context.mounted) navigator.pop();
    } catch (e) {
      if (!context.mounted) return;
      await _handleError(context, operation: 'delete', action: action, error: e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _handleError(
    BuildContext context, {
    required String operation,
    required Future<void> Function() action,
    required Object error,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ErrorDialog(
        message: 'Nao foi possivel concluir a operacao. Tente novamente.',
        onRetry: () async {
          try {
            await action();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          } catch (_) {}
        },
        onCancel: () {
          TelemetryService.instance.logAbandonAfterFailure(operation);
        },
      ),
    );
  }
}
