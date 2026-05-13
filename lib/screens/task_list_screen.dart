import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/debug_admin.dart';
import '../domain/models/task.dart';
import 'admin/admin_participants_screen.dart';
import '../providers/task_provider.dart';
import '../utils/task_list_error_messages.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/task_card.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

enum _TaskFilter { all, pending, completed }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  _TaskFilter _filter = _TaskFilter.all;
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasks;

    final filtered = switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.pending => tasks.where((t) => !t.isCompleted).toList(),
      _TaskFilter.completed => tasks.where((t) => t.isCompleted).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        actions: [
          if (isDebugAdminBuild)
            IconButton(
              tooltip: 'Investigador',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminParticipantsScreen(),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Recarregar lista',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(taskProvider.refreshTasks()),
          ),
          IconButton(
            tooltip: 'Configuracoes e exportacao',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<_TaskFilter>(
              segments: const [
                ButtonSegment<_TaskFilter>(
                  value: _TaskFilter.all,
                  label: Text('Todas'),
                ),
                ButtonSegment<_TaskFilter>(
                  value: _TaskFilter.pending,
                  label: Text('Pendentes'),
                ),
                ButtonSegment<_TaskFilter>(
                  value: _TaskFilter.completed,
                  label: Text('Concluidas'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() {
                  _filter = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _buildMainContent(context, taskProvider, filtered, tasks),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaskFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    TaskProvider taskProvider,
    List<Task> filtered,
    List<Task> allTasks,
  ) {
    if (taskProvider.showBlockingLoader) {
      return const LoadingIndicator(message: 'Carregando tarefas...');
    }

    final errMsg = taskProvider.loadErrorMessage;
    if (errMsg != null && allTasks.isEmpty) {
      return _connectionErrorPanel(context, errMsg, taskProvider);
    }

    final banner =
        errMsg != null && allTasks.isNotEmpty
            ? _connectionWarningBanner(context, errMsg, taskProvider)
            : null;

    if (filtered.isEmpty) {
      if (banner != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            banner,
            const Expanded(
              child: Center(child: Text('Nenhuma tarefa encontrada.')),
            ),
          ],
        );
      }
      return const Center(child: Text('Nenhuma tarefa encontrada.'));
    }

    final listCore =
        _filter != _TaskFilter.all
            ? _filteredListView(context, taskProvider, filtered)
            : _reorderableListView(context, taskProvider, filtered);

    final withRefresh = RefreshIndicator(
      onRefresh: taskProvider.refreshTasks,
      child: listCore,
    );

    if (banner != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner,
          Expanded(child: withRefresh),
        ],
      );
    }
    return withRefresh;
  }

  Widget _connectionErrorPanel(
    BuildContext context,
    String message,
    TaskProvider taskProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_find_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => unawaited(taskProvider.refreshTasks()),
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar lista'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionWarningBanner(
    BuildContext context,
    String message,
    TaskProvider taskProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: scheme.onErrorContainer,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(taskProvider.refreshTasks()),
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filteredListView(
    BuildContext context,
    TaskProvider taskProvider,
    List<Task> filtered,
  ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: filtered.length,
      itemBuilder: (context, index) =>
          _buildTaskCard(context, taskProvider, filtered[index]),
    );
  }

  Widget _reorderableListView(
    BuildContext context,
    TaskProvider taskProvider,
    List<Task> filtered,
  ) {
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: filtered.length,
      buildDefaultDragHandles: true,
      onReorder:
          _reordering
              ? (_, __) {}
              : (oldIndex, newIndex) async {
                final messenger = ScaffoldMessenger.of(context);
                if (newIndex > oldIndex) newIndex -= 1;
                final reordered = List.of(filtered);
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                setState(() => _reordering = true);
                try {
                  await taskProvider.reorderTasks(reordered);
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Falha ao reordenar: ${taskListLoadErrorMessage(e)}',
                      ),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _reordering = false);
                }
              },
      itemBuilder: (context, index) {
        final task = filtered[index];
        return Container(
          key: ValueKey(task.id),
          margin: const EdgeInsets.only(bottom: 6),
          child: _buildTaskCard(context, taskProvider, task),
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskProvider taskProvider,
    Task task,
  ) {
    return TaskCard(
      task: task,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: task),
          ),
        );
      },
      onCompletedChanged: (checked) async {
        await taskProvider.updateTask(
          task.copyWith(
            isCompleted: checked,
            updatedAt: DateTime.now(),
          ),
        );
      },
    );
  }
}
