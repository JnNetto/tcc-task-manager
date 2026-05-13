import 'package:hive/hive.dart';

import '../domain/models/participant_study_config.dart';
import '../domain/repositories/task_repository.dart';
import 'offline/offline_task_repository.dart';
import 'offline/task_hive_model.dart';
import 'online/online_task_repository.dart';

/// Agrega o [TaskRepository] ativo e a instância offline usada pelo [SyncService]
/// (mesma referência que o repositório ativo em modo offline-first).
class StudyRepositoryBundle {
  const StudyRepositoryBundle({
    required this.activeRepository,
    required this.offlineRepositoryForSync,
  });

  final TaskRepository activeRepository;

  /// Só não nulo em `offline-first`; é a mesma instância injetada como ativa.
  final OfflineTaskRepository? offlineRepositoryForSync;
}

/// Fábrica central para escolher repositório consoante a arquitetura remota.
class StudyRepositoryFactory {
  StudyRepositoryFactory._();

  static StudyRepositoryBundle build({
    required ParticipantStudyConfig cfg,
    required Box<TaskHiveModel> tasksBox,
    required String participantId,
  }) {
    final offline = OfflineTaskRepository(tasksBox);
    final online = OnlineTaskRepository(participantId: participantId);
    if (cfg.isOfflineFirst) {
      return StudyRepositoryBundle(
        activeRepository: offline,
        offlineRepositoryForSync: offline,
      );
    }
    return StudyRepositoryBundle(
      activeRepository: online,
      offlineRepositoryForSync: null,
    );
  }
}
