class AppConfig {
  /// Duracao de cada periodo experimental em dias.
  /// Definir antes do inicio da coleta. 0 = ainda nao definido.
  static const int periodDurationDays = 30; // alinhado ao protocolo v4.1 (15+15 referência)

  /// CAMADA 1: janelas fixas por horario.
  /// Identicas para os dois prototipos - principio da simetria.
  static const List<SimulationWindow> networkDegradationWindows = [
    SimulationWindow(startHour: 7, startMinute: 30, durationMinutes: 30),
    SimulationWindow(startHour: 12, startMinute: 0, durationMinutes: 20),
    SimulationWindow(startHour: 17, startMinute: 30, durationMinutes: 30),
    SimulationWindow(startHour: 20, startMinute: 0, durationMinutes: 60),
    SimulationWindow(startHour: 22, startMinute: 30, durationMinutes: 20),
  ];

  /// CAMADA 2: degradacao por volume de operacoes.
  /// A cada N operacoes bem-sucedidas, as proximas M sao degradadas.
  static const int degradationEveryNOps = 4;
  static const int degradationDurationOps = 2;

  /// Modo de degradacao aplicado durante as janelas.
  static const DegradationMode degradationMode =
      DegradationMode.blockAndLatency;

  /// Latencia simulada quando aplicavel (ms).
  static const int simulatedLatencyMs = 3000;
}

class SimulationWindow {
  final int startHour;
  final int startMinute;
  final int durationMinutes;

  const SimulationWindow({
    required this.startHour,
    required this.startMinute,
    required this.durationMinutes,
  });
}

enum DegradationMode {
  blockOnly,
  latencyOnly,
  blockAndLatency,
}
