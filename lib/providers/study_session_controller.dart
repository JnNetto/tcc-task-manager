import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/experiment/participant_remote_config_service.dart';
import '../domain/models/participant_study_config.dart';

/// Estado remoto do estudo (arquitetura ativa, flags, perfil) com atualização periódica.
/// Substitui o antigo [ExperimentProvider] fixo por protótipo.
class StudySessionController extends ChangeNotifier with WidgetsBindingObserver {
  StudySessionController({
    required this.participantId,
    required this.studyStartDate,
    required ParticipantRemoteConfigService remote,
    this.pollInterval = const Duration(seconds: 30),
    this.onArchitectureTransition,
    ParticipantStudyConfig? fixedConfig,
  })  : _remote = remote,
        _fixedConfig = fixedConfig {
    WidgetsBinding.instance.addObserver(this);
    if (_fixedConfig != null) {
      _config = _fixedConfig;
      notifyListeners();
    } else {
      _listenParticipantNode();
      unawaited(refreshRemoteConfig());
      _timer = Timer.periodic(
        pollInterval,
        (_) => unawaited(refreshRemoteConfig()),
      );
    }
  }

  final String participantId;
  final DateTime studyStartDate;
  final ParticipantRemoteConfigService _remote;
  final Duration pollInterval;
  final ParticipantStudyConfig? _fixedConfig;

  /// Chamado quando a arquitetura remota muda (ex.: flush Hive → Firestore ao sair de offline-first).
  final Future<void> Function(String oldArchitecture, String newArchitecture)?
      onArchitectureTransition;

  ParticipantStudyConfig? _config;
  Object? _lastError;
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _rtdbParticipantSub;
  Future<void> _refreshQueue = Future<void>.value();

  ParticipantStudyConfig? get remoteConfig => _config;
  Object? get lastRemoteError => _lastError;

  /// Valor alinhado ao campo RTDB `architecture`.
  String get prototype =>
      _config?.architecture ?? ParticipantStudyConfig.kOnlineFirst;

  bool get isOnlineFirst => prototype == ParticipantStudyConfig.kOnlineFirst;
  bool get isOfflineFirst => prototype == ParticipantStudyConfig.kOfflineFirst;
  bool get appEnabled => _config?.appEnabled ?? true;
  bool get telemetryEnabled => _config?.telemetryEnabled ?? true;
  bool get profileComplete => _config?.profileComplete ?? false;

  int get dayOfStudy => DateTime.now().difference(studyStartDate).inDays + 1;

  Future<void> refreshRemoteConfig() async {
    final ticket = Completer<void>();
    final previous = _refreshQueue;
    _refreshQueue = ticket.future;
    await previous;
    try {
      if (_fixedConfig != null) {
        _config = _fixedConfig;
        return;
      }
      try {
        if (await _remote.fetchParticipant(participantId) == null) {
          _lastError = StateError('participant_not_found');
          notifyListeners();
          return;
        }
        final resolved =
            await _remote.ensureEnrollmentMetaAndPhaseTally(participantId);
        _lastError = null;
        final prev = _config;
        if (prev != null &&
            prev.architecture != resolved.architecture &&
            onArchitectureTransition != null) {
          await onArchitectureTransition!(
            prev.architecture,
            resolved.architecture,
          );
        }
        _config = resolved;
        if (prev == null ||
            prev.architecture != resolved.architecture ||
            prev.appEnabled != resolved.appEnabled ||
            prev.telemetryEnabled != resolved.telemetryEnabled ||
            prev.profileComplete != resolved.profileComplete ||
            prev.daysOnlinePhase != resolved.daysOnlinePhase ||
            prev.daysOfflinePhase != resolved.daysOfflinePhase) {
          notifyListeners();
        }
      } catch (e, st) {
        _lastError = e;
        if (kDebugMode) {
          debugPrint('StudySessionController.refresh error: $e\n$st');
        }
        notifyListeners();
      }
    } finally {
      ticket.complete();
    }
  }

  void _listenParticipantNode() {
    _rtdbParticipantSub?.cancel();
    _rtdbParticipantSub = FirebaseDatabase.instance
        .ref('participants/$participantId')
        .onValue
        .listen((_) {
      unawaited(refreshRemoteConfig());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_fixedConfig != null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshRemoteConfig());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rtdbParticipantSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
