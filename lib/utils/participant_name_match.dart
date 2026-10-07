/// Compara nome informado pelo participante com o cadastrado no RTDB.
bool participantNamesMatch(String entered, String registered) {
  return _normalizeName(entered) == _normalizeName(registered);
}

String _normalizeName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
