import 'dart:async';

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
    this.pollInterval = const Duration(minutes: 2),
    ParticipantStudyConfig? fixedConfig,
  })  : _remote = remote,
        _fixedConfig = fixedConfig {
    WidgetsBinding.instance.addObserver(this);
    if (_fixedConfig != null) {
      _config = _fixedConfig;
      notifyListeners();
    } else {
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

  ParticipantStudyConfig? _config;
  Object? _lastError;
  Timer? _timer;

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
    if (_fixedConfig != null) {
      _config = _fixedConfig;
      return;
    }
    try {
      final next = await _remote.fetchParticipant(participantId);
      if (next == null) {
        _lastError = StateError('participant_not_found');
        notifyListeners();
        return;
      }
      _lastError = null;
      final prev = _config;
      _config = next;
      if (prev == null ||
          prev.architecture != next.architecture ||
          prev.appEnabled != next.appEnabled ||
          prev.telemetryEnabled != next.telemetryEnabled ||
          prev.profileComplete != next.profileComplete) {
        notifyListeners();
      }
    } catch (e, st) {
      _lastError = e;
      if (kDebugMode) {
        debugPrint('StudySessionController.refresh error: $e\n$st');
      }
      notifyListeners();
    }
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
    _timer?.cancel();
    super.dispose();
  }
}
