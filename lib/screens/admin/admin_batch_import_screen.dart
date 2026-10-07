import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/experiment/admin_study_remote_service.dart';
import '../../domain/models/participant_study_config.dart';

class _ParsedParticipant {
  const _ParsedParticipant({
    required this.digits,
    required this.displayName,
    required this.architecture,
  });
  final String digits;
  final String displayName;
  final String architecture;
}

enum _ImportStatus { pending, success, error }

class _ImportResult {
  _ImportResult(this.participant) : status = _ImportStatus.pending;
  final _ParsedParticipant participant;
  _ImportStatus status;
  String? errorMessage;
}

/// Tela de importação em lote de participantes a partir de txt colado.
/// Formato esperado por linha:  `026 - Nome - Offline`  ou  `017 - Nome - Online`
class AdminBatchImportScreen extends StatefulWidget {
  const AdminBatchImportScreen({super.key});

  @override
  State<AdminBatchImportScreen> createState() => _AdminBatchImportScreenState();
}

class _AdminBatchImportScreenState extends State<AdminBatchImportScreen> {
  final _textCtrl = TextEditingController();
  final _service = AdminStudyRemoteService();

  List<_ParsedParticipant>? _parsed;
  List<_ImportResult>? _results;
  bool _importing = false;
  bool _done = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // Regex: `026 - Any Name Here - Offline`
  static final _lineRegex = RegExp(
    r'^(\d{3})\s*-\s*(.+?)\s*-\s*(Online|Offline)\s*$',
    caseSensitive: false,
  );

  List<_ParsedParticipant> _parse(String text) {
    final out = <_ParsedParticipant>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final m = _lineRegex.firstMatch(trimmed);
      if (m == null) continue;
      final arch = m.group(3)!.toLowerCase() == 'offline'
          ? ParticipantStudyConfig.kOfflineFirst
          : ParticipantStudyConfig.kOnlineFirst;
      out.add(_ParsedParticipant(
        digits: m.group(1)!,
        displayName: m.group(2)!.trim(),
        architecture: arch,
      ));
    }
    return out;
  }

  void _preview() {
    setState(() {
      _parsed = _parse(_textCtrl.text);
      _results = null;
      _done = false;
    });
  }

  Future<void> _import() async {
    assert(kDebugMode);
    final parsed = _parsed;
    if (parsed == null || parsed.isEmpty) return;

    final results = parsed.map(_ImportResult.new).toList();
    setState(() {
      _results = results;
      _importing = true;
      _done = false;
    });

    for (final r in results) {
      try {
        await _service.createParticipant(
          digits: r.participant.digits,
          displayName: r.participant.displayName,
          architecture: r.participant.architecture,
        );
        r.status = _ImportStatus.success;
      } catch (e) {
        r.status = _ImportStatus.error;
        r.errorMessage = e.toString();
      }
      if (mounted) setState(() {});
    }

    if (mounted) setState(() { _importing = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar participantes em lote')),
      body: AbsorbPointer(
        absorbing: _importing,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Cole o conteudo do arquivo txt. Formato esperado por linha:\n'
              '  026 - Nome - Offline\n'
              '  017 - Nome - Online\n\n'
              'Linhas com formato invalido sao ignoradas.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (!_done)
              TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Conteudo do txt',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                enabled: !_importing,
              ),
            if (!_importing && !_done) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.preview),
                label: const Text('Pre-visualizar'),
              ),
            ],
            if (parsed != null && results == null) ...[
              const SizedBox(height: 20),
              Text(
                '${parsed.length} participante(s) reconhecido(s):',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...parsed.map((p) => _PreviewTile(p: p)),
              const SizedBox(height: 16),
              if (parsed.isNotEmpty)
                FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload),
                  label: Text('Criar ${parsed.length} participante(s) no Firebase'),
                ),
            ],
            if (results != null) ...[
              const SizedBox(height: 16),
              Text(
                _done ? 'Importacao concluida!' : 'Importando...',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...results.map((r) => _ResultTile(r: r)),
              if (_done) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir e atualizar lista'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.p});
  final _ParsedParticipant p;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Text(
        'P${p.digits}',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      title: Text(p.displayName),
      subtitle: Text(p.architecture),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.r});
  final _ImportResult r;

  @override
  Widget build(BuildContext context) {
    final icon = switch (r.status) {
      _ImportStatus.pending => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _ImportStatus.success =>
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
      _ImportStatus.error =>
        const Icon(Icons.error, color: Colors.red, size: 20),
    };

    return ListTile(
      dense: true,
      leading: icon,
      title: Text('P${r.participant.digits} — ${r.participant.displayName}'),
      subtitle: r.errorMessage != null ? Text(r.errorMessage!) : null,
    );
  }
}
