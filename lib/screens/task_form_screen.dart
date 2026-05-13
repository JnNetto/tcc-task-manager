import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/task.dart';
import '../domain/models/task_priority.dart';
import '../domain/models/sync_status.dart';
import '../providers/study_session_controller.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/common/error_dialog.dart';
import '../widgets/common/loading_indicator.dart';

enum _ReminderType { none, single, daily }

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _uuid = const Uuid();

  TaskPriority _priority = TaskPriority.medium;
  _ReminderType _reminderType = _ReminderType.none;
  DateTime? _singleReminderAt;
  DateTime? _reminderEndDate;
  final List<TimeOfDay> _dailyTimes = [];
  final Set<int> _selectedWeekdays = {};
  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descriptionCtrl.text = t.description ?? '';
      _priority = t.priority;
      _reminderEndDate = t.reminderEndDate;

      if (t.isRecurring) {
        _reminderType = _ReminderType.daily;
        _selectedWeekdays
          ..clear()
          ..addAll(
            t.recurringWeekdays.isEmpty
                ? const {1, 2, 3, 4, 5, 6, 7}
                : t.recurringWeekdays,
          );
        for (int i = 0; i < t.recurringHours.length; i++) {
          _dailyTimes.add(
            TimeOfDay(hour: t.recurringHours[i], minute: t.recurringMinutes[i]),
          );
        }
      } else if (t.reminderAt != null) {
        _reminderType = _ReminderType.single;
        _singleReminderAt = t.reminderAt;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar Tarefa' : 'Nova Tarefa'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Titulo *'),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) return 'Informe um titulo';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descricao (opcional)'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TaskPriority>(
                      key: ValueKey(_priority),
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                      items: TaskPriority.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _priority = v ?? _priority),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<_ReminderType>(
                      key: ValueKey(_reminderType),
                      initialValue: _reminderType,
                      decoration: const InputDecoration(labelText: 'Lembrete'),
                      items: const [
                        DropdownMenuItem(
                          value: _ReminderType.none,
                          child: Text('Sem lembrete'),
                        ),
                        DropdownMenuItem(
                          value: _ReminderType.single,
                          child: Text('Unico'),
                        ),
                        DropdownMenuItem(
                          value: _ReminderType.daily,
                          child: Text('Diario'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _reminderType = v ?? _reminderType),
                    ),
                    const SizedBox(height: 12),
                    if (_reminderType == _ReminderType.single) _singleReminderSection(),
                    if (_reminderType == _ReminderType.daily) _dailyReminderSection(),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _onSavePressed,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ),
            if (_saving)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: LoadingIndicator(message: 'Salvando...'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _singleReminderSection() {
    return Card(
      child: ListTile(
        title: const Text('Horario do lembrete'),
        subtitle: Text(
          _singleReminderAt == null
              ? 'Nao definido'
              : _singleReminderAt.toString(),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.schedule),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              initialDate: _singleReminderAt ?? DateTime.now(),
            );
            if (date == null) return;
            if (!mounted) return;
            final tod = await showTimePicker(
              context: context,
              initialTime: _singleReminderAt != null
                  ? TimeOfDay.fromDateTime(_singleReminderAt!)
                  : TimeOfDay.now(),
            );
            if (tod == null) return;
            if (!mounted) return;
            setState(() {
              _singleReminderAt = DateTime(
                date.year,
                date.month,
                date.day,
                tod.hour,
                tod.minute,
              );
            });
          },
        ),
      ),
    );
  }

  Widget _dailyReminderSection() {
    const weekdayOptions = <int, String>{
      1: 'Seg',
      2: 'Ter',
      3: 'Qua',
      4: 'Qui',
      5: 'Sex',
      6: 'Sab',
      7: 'Dom',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dias da semana'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekdayOptions.entries.map((entry) {
            final selected = _selectedWeekdays.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selectedWeekdays.add(entry.key);
                  } else {
                    _selectedWeekdays.remove(entry.key);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Horarios diarios'),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (t == null) return;
                if (!mounted) return;
                setState(() => _dailyTimes.add(t));
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (_dailyTimes.isEmpty)
          const Text('Nenhum horario adicionado')
        else
          ..._dailyTimes.asMap().entries.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value.format(context)),
              trailing: IconButton(
                onPressed: () {
                  setState(() => _dailyTimes.removeAt(entry.key));
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data limite (opcional)'),
          subtitle: Text(
            _reminderEndDate == null ? 'Sem limite' : _reminderEndDate.toString(),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: _reminderEndDate ?? DateTime.now(),
              );
              if (date == null) return;
              setState(() => _reminderEndDate = date);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onSavePressed() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<TaskProvider>();
    final now = DateTime.now();
    final prev = widget.task;

    final reminderAt = _reminderType == _ReminderType.single ? _singleReminderAt : null;
    final isRecurring = _reminderType == _ReminderType.daily;
    final recurringHours = isRecurring ? _dailyTimes.map((t) => t.hour).toList() : <int>[];
    final recurringMinutes = isRecurring
        ? _dailyTimes.map((t) => t.minute).toList()
        : <int>[];
    final recurringWeekdays = isRecurring
        ? (_selectedWeekdays.isEmpty
              ? <int>[1, 2, 3, 4, 5, 6, 7]
              : _selectedWeekdays.toList()..sort())
        : <int>[];

    final task = Task(
      id: prev?.id ?? _uuid.v4(),
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      isCompleted: prev?.isCompleted ?? false,
      priority: _priority,
      createdAt: prev?.createdAt ?? now,
      updatedAt: now,
      syncStatus: prev?.syncStatus ?? _defaultSyncForCreate(context),
      pendingSince: prev?.pendingSince,
      reminderAt: reminderAt,
      isRecurring: isRecurring,
      recurringHours: recurringHours,
      recurringMinutes: recurringMinutes,
      recurringWeekdays: recurringWeekdays,
      reminderEndDate: isRecurring ? _reminderEndDate : null,
    );

    Future<void> saveAction() async {
      if (_isEdit) {
        await repo.updateTask(task);
      } else {
        await repo.createTask(task);
      }
      // Lembrete é best-effort: falha no agendamento não deve apagar o sucesso
      // em Firestore/offline nem mostrar erro como se a tarefa não tivesse sido guardada.
      try {
        if (_isEdit) {
          await NotificationService.rescheduleForTask(task);
        } else if (task.reminderAt != null || task.isRecurring) {
          await NotificationService.scheduleForTask(task);
        }
      } catch (e, st) {
        debugPrint('Agendamento de lembrete apos guardar tarefa: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tarefa guardada. O lembrete pode nao ter sido agendado — '
                'verifique permissoes de notificacao nas definicoes.',
              ),
            ),
          );
        }
      }
    }

    try {
      setState(() => _saving = true);
      await saveAction();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(
          message: 'Nao foi possivel guardar. Tente novamente.',
          onRetry: () async {
            try {
              await saveAction();
              if (mounted) Navigator.of(context).pop();
            } catch (_) {}
          },
          onCancel: () {
            TelemetryService.instance.logAbandonAfterFailure(
              _isEdit ? 'update' : 'create',
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SyncStatus _defaultSyncForCreate(BuildContext context) {
    final experiment = context.read<StudySessionController>();
    return experiment.isOfflineFirst ? SyncStatus.pending : SyncStatus.synced;
  }
}
