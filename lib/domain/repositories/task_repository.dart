import '../models/task.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchTasks();
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String taskId);

  /// Busca uma tarefa pontual (necessario para a tela de detalhes
  /// e para o NotificationService recuperar dados ao agendar).
  Future<Task?> getTaskById(String taskId);
}
