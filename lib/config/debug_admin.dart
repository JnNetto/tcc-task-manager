import 'package:flutter/foundation.dart';

/// Em build **debug**, o app funciona como consola do investigador (P000, sem onboarding).
bool get isDebugAdminBuild => kDebugMode;

/// Identidade fixa do investigador na sessão debug (não participa como sujeito do estudo).
const String kDebugAdminParticipantId = 'P000';
