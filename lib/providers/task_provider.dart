import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/task.dart';
import '../domain/repositories/task_repository.dart';
import '../utils/task_list_error_messages.dart';

class TaskProvider extends ChangeNotifier {
  static const _kTaskOrderIds = 'task_order_ids_v1';
  TaskRepository _repository;
  StreamSubscription<List<Task>>? _sub;
  List<String> _orderedIds = const [];

  List<Task> _tasks = const [];
  bool _loading = false;
  Object? _error;

  TaskProvider(this._repository) {
    _init();
  }

  /// Troca o repositório (ex.: arquitetura remota alterada) e volta a subscrever a lista.
  void attachRepository(TaskRepository repository) {
    _sub?.cancel();
    _sub = null;
    _repository = repository;
    _tasks = const [];
    _error = null;
    unawaited(_init());
  }

  List<Task> get tasks => _tasks;
  bool get isLoading => _loading;

  /// Erro bruto da stream (telemetria / debug).
  Object? get error => _error;

  /// Mensagem para mostrar ao utilizador (sem `OfflineException`, etc.).
  String? get loadErrorMessage =>
      _error != null ? taskListLoadErrorMessage(_error) : null;

  /// Lista vazia + a carregar: ecrã de espera completo. Com dados em cache, o recarregar não bloqueia a lista.
  bool get showBlockingLoader => _loading && _tasks.isEmpty;

  Future<void> _init() async {
    await _loadOrder();
    _bind();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTaskOrderIds);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = (jsonDecode(raw) as List).cast<String>();
      _orderedIds = decoded;
    } catch (_) {
      _orderedIds = const [];
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTaskOrderIds, jsonEncode(_orderedIds));
  }

  List<Task> _applyManualOrder(List<Task> incoming) {
    if (_orderedIds.isEmpty) return incoming;
    final byId = {for (final t in incoming) t.id: t};
    final ordered = <Task>[];
    for (final id in _orderedIds) {
      final task = byId.remove(id);
      if (task != null) ordered.add(task);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  /// Volta a subscrever a lista (útil na janela de degradação ou após falha de rede).
  Future<void> refreshTasks() async {
    await _sub?.cancel();
    _sub = null;
    _error = null;
    notifyListeners();
    _bind(isRefresh: _tasks.isNotEmpty);
  }

  void _bind({bool isRefresh = false}) {
    if (!isRefresh) {
      _loading = true;
    }
    notifyListeners();
    _sub = _repository.watchTasks().listen(
      (data) {
        _tasks = _applyManualOrder(data);
        final normalizedIds = _tasks.map((t) => t.id).toList();
        if (!listEquals(_orderedIds, normalizedIds)) {
          _orderedIds = normalizedIds;
          unawaited(_saveOrder());
        }
        _error = null;
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e;
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> createTask(Task task) => _repository.createTask(task);
  Future<void> updateTask(Task task) => _repository.updateTask(task);
  Future<void> reorderTasks(List<Task> orderedTasks) async {
    _tasks = orderedTasks;
    _orderedIds = orderedTasks.map((t) => t.id).toList();
    notifyListeners();
    await _saveOrder();
  }
  Future<void> deleteTask(String taskId) => _repository.deleteTask(taskId);
  Future<Task?> getTaskById(String taskId) => _repository.getTaskById(taskId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
