import 'dart:async';

import '../config/app_config.dart';
import 'telemetry_service.dart';

class NetworkSimulator {
  static final NetworkSimulator instance = NetworkSimulator._();
  NetworkSimulator._();

  Timer? _windowCheckTimer;
  bool _inTimeWindow = false;
  int _opsSucceededSinceLastDegradation = 0;
  int _opsDegradedRemaining = 0;
  bool _inOpDegradation = false;

  bool get isConnected => !isDegraded;
  bool get isDegraded => _inTimeWindow || _inOpDegradation;

  DegradationCause get degradationCause {
    if (_inTimeWindow && _inOpDegradation) return DegradationCause.both;
    if (_inTimeWindow) return DegradationCause.timeWindow;
    if (_inOpDegradation) return DegradationCause.opBased;
    return DegradationCause.none;
  }

  void start() {
    _checkWindow();
    _windowCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkWindow(),
    );
  }

  void _checkWindow() {
    final now = DateTime.now();
    final inWindow = AppConfig.networkDegradationWindows.any((w) {
      final windowStart = DateTime(
        now.year,
        now.month,
        now.day,
        w.startHour,
        w.startMinute,
      );
      final windowEnd = windowStart.add(Duration(minutes: w.durationMinutes));
      return now.isAfter(windowStart) && now.isBefore(windowEnd);
    });

    if (inWindow != _inTimeWindow) {
      _inTimeWindow = inWindow;
      TelemetryService.instance.logNetworkWindowChanged(
        degraded: isDegraded,
        cause: degradationCause.name,
        timestamp: now,
      );
    }
  }

  void _recordOperationOutcome(bool succeeded) {
    if (_inOpDegradation) {
      if (!succeeded) return;
      _opsDegradedRemaining--;
      if (_opsDegradedRemaining <= 0) {
        _inOpDegradation = false;
        _opsSucceededSinceLastDegradation = 0;
        TelemetryService.instance.logEvent('op_degradation_window_ended');
      }
    } else if (succeeded) {
      _opsSucceededSinceLastDegradation++;
      if (_opsSucceededSinceLastDegradation >= AppConfig.degradationEveryNOps) {
        _inOpDegradation = true;
        _opsDegradedRemaining = AppConfig.degradationDurationOps;
        _opsSucceededSinceLastDegradation = 0;
        TelemetryService.instance.logEvent('op_degradation_window_started');
      }
    }
  }

  Future<void> _delayBeforeFailure(String operationName) async {
    TelemetryService.instance.logOperationDelayed(
      operationName,
      AppConfig.simulatedLatencyMs,
      cause: degradationCause.name,
    );
    await Future.delayed(
      const Duration(milliseconds: AppConfig.simulatedLatencyMs),
    );
  }

  Future<void> intercept(
    String operationName,
    Future<void> Function() operation,
  ) async {
    if (!isDegraded) {
      try {
        await operation();
        _recordOperationOutcome(true);
      } catch (_) {
        _recordOperationOutcome(false);
        rethrow;
      }
      return;
    }

    switch (AppConfig.degradationMode) {
      case DegradationMode.blockOnly:
        _recordOperationOutcome(false);
        await _delayBeforeFailure(operationName);
        TelemetryService.instance.logOperationBlocked(
          operationName,
          cause: degradationCause.name,
        );
        throw OfflineException('Sem conexao. Tente novamente mais tarde.');
      case DegradationMode.latencyOnly:
        TelemetryService.instance.logOperationDelayed(
          operationName,
          AppConfig.simulatedLatencyMs,
          cause: degradationCause.name,
        );
        await Future.delayed(
          const Duration(milliseconds: AppConfig.simulatedLatencyMs),
        );
        await operation();
        _recordOperationOutcome(true);
        return;
      case DegradationMode.blockAndLatency:
        final blocked = DateTime.now().millisecond % 10 < 6;
        if (blocked) {
          _recordOperationOutcome(false);
          await _delayBeforeFailure(operationName);
          TelemetryService.instance.logOperationBlocked(
            operationName,
            cause: degradationCause.name,
          );
          throw OfflineException('Sem conexao. Tente novamente mais tarde.');
        } else {
          TelemetryService.instance.logOperationDelayed(
            operationName,
            AppConfig.simulatedLatencyMs,
            cause: degradationCause.name,
          );
          await Future.delayed(
            const Duration(milliseconds: AppConfig.simulatedLatencyMs),
          );
          await operation();
          _recordOperationOutcome(true);
          return;
        }
    }
  }

  Future<bool> checkSyncAllowed(String context) async {
    if (!isDegraded) return true;
    TelemetryService.instance.logSyncBlocked(
      reason: '${degradationCause.name}:$context',
    );
    return false;
  }

  void dispose() {
    _windowCheckTimer?.cancel();
  }
}

class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);

  @override
  String toString() => 'OfflineException: $message';
}

enum DegradationCause { none, timeWindow, opBased, both }
