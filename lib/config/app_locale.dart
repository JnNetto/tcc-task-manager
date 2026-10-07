import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Locale e delegates partilhados por todos os [MaterialApp] (calendário e relógio
/// dos lembretes em português).
abstract final class AppLocale {
  AppLocale._();

  /// Português (Brasil): nomes de meses, botões Cancelar/OK nos pickers, etc.
  static const Locale defaultLocale = Locale('pt', 'BR');

  static const List<Locale> supportedLocales = [
    Locale('pt', 'BR'),
    Locale('pt'),
  ];

  static const List<LocalizationsDelegate<dynamic>> delegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
