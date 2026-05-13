import 'package:firebase_core/firebase_core.dart';

import '../services/network_simulator.dart';

/// Mensagens para o utilizador (sem nomes de classes nem stack traces).
String taskListLoadErrorMessage(Object? error) {
  if (error == null) return '';

  if (error is OfflineException) {
    return 'Problema de conexão. Verifique a rede ou tente novamente em instantes.';
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'network-request-failed':
        return 'Problema de conexão com o servidor. Tente novamente.';
      default:
        return 'Não foi possível carregar as tarefas. Tente recarregar a lista.';
    }
  }

  return 'Problema de conexão ou de servidor. Tente recarregar a lista.';
}
