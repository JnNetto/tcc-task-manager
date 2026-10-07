import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/experiment/admin_study_remote_service.dart';
import '../../domain/models/participant_study_config.dart';
import '../../domain/models/subjective_questionnaire_payload.dart';

enum _ImportStatus { pending, success, error }

class _QuestionnaireImportPreview {
  _QuestionnaireImportPreview({
    required this.fileName,
    required this.payload,
    required this.assignedArchitecture,
    required this.architectureDuringPeriod,
    required this.displayName,
    required this.participantExists,
    this.existingImportedAt,
  });

  final String fileName;
  final SubjectiveQuestionnairePayload payload;
  final String assignedArchitecture;
  final String architectureDuringPeriod;
  final String displayName;
  final bool participantExists;
  final String? existingImportedAt;
}

class _QuestionnaireImportResult {
  _QuestionnaireImportResult(this.preview) : status = _ImportStatus.pending;

  final _QuestionnaireImportPreview preview;
  _ImportStatus status;
  String? errorMessage;
  SubjectiveQuestionnaireImportRecord? saved;
}

/// Importa arquivos `.json` ou `.txt` com JSON (`respostas_T1_*`, `respostas_T2_*`).
class AdminQuestionnaireImportScreen extends StatefulWidget {
  const AdminQuestionnaireImportScreen({super.key});

  @override
  State<AdminQuestionnaireImportScreen> createState() =>
      _AdminQuestionnaireImportScreenState();
}

class _AdminQuestionnaireImportScreenState
    extends State<AdminQuestionnaireImportScreen> {
  final _service = AdminStudyRemoteService();

  List<_QuestionnaireImportPreview>? _previews;
  List<_QuestionnaireImportResult>? _results;
  bool _loading = false;
  bool _importing = false;
  bool _done = false;
  String? _pickError;

  Future<void> _pickFiles() async {
    setState(() {
      _pickError = null;
      _previews = null;
      _results = null;
      _done = false;
      _loading = true;
    });

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
        allowMultiple: true,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final previews = <_QuestionnaireImportPreview>[];
      final errors = <String>[];

      for (final file in picked.files) {
        final name = file.name;
        final bytes = file.bytes;
        if (bytes == null) {
          errors.add('$name: conteudo indisponivel.');
          continue;
        }
        try {
          final text = _readFileText(bytes);
          final payload = SubjectiveQuestionnairePayload.parseJsonString(text);
          final cfg = await _service.fetchParticipantConfig(payload.participantId);
          final exists = cfg != null;
          final assigned = cfg?.architecture ?? ParticipantStudyConfig.kOnlineFirst;
          final archDuring =
              SubjectiveQuestionnairePayload.architectureDuringPeriod(
            assignedArchitecture: assigned,
            period: payload.period,
          );
          String? existingAt;
          if (exists) {
            final status = await _service.fetchSubjectiveQuestionnaireStatus(
              payload.participantId,
            );
            existingAt = status[payload.period]?.importedAt;
          }
          previews.add(
            _QuestionnaireImportPreview(
              fileName: name,
              payload: payload,
              assignedArchitecture: assigned,
              architectureDuringPeriod: archDuring,
              displayName:
                  cfg?.registeredParticipantName ?? payload.participantId,
              participantExists: exists,
              existingImportedAt: existingAt,
            ),
          );
        } catch (e) {
          errors.add('$name: $e');
        }
      }

      if (mounted) {
        setState(() {
          _previews = previews;
          _pickError = errors.isEmpty ? null : errors.join('\n');
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickError = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _readFileText(List<int> bytes) {
    var text = utf8.decode(bytes);
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    return text.trim();
  }

  Future<void> _importAll() async {
    assert(kDebugMode);
    final previews = _previews;
    if (previews == null || previews.isEmpty) return;

    final importable = previews.where((p) => p.participantExists).toList();
    if (importable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum arquivo com participante valido no RTDB.'),
        ),
      );
      return;
    }

    final results = importable.map(_QuestionnaireImportResult.new).toList();
    setState(() {
      _results = results;
      _importing = true;
      _done = false;
    });

    for (final r in results) {
      try {
        r.saved = await _service.importSubjectiveQuestionnaire(r.preview.payload);
        r.status = _ImportStatus.success;
      } catch (e) {
        r.status = _ImportStatus.error;
        r.errorMessage = e.toString();
      }
      if (mounted) setState(() {});
    }

    if (mounted) {
      setState(() {
        _importing = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previews = _previews;
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar questionarios subjetivos')),
      body: AbsorbPointer(
        absorbing: _loading || _importing,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Selecione um ou mais arquivos .json ou .txt com estrutura JSON '
              'gerados pelos formularios HTML '
              '(T1 = primeiros 15 dias, T2 = ultimos 15 dias).\n\n'
              'O sistema identifica o participante pelo codigo no JSON, '
              'resolve a arquitetura vigente no periodo (online-first ou '
              'offline-first) e grava em '
              '`participants/{id}/subjective_questionnaires/{T1|T2}`.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (!_done)
              FilledButton.icon(
                onPressed: _loading ? null : _pickFiles,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(
                  _loading ? 'Lendo arquivos...' : 'Selecionar JSON ou TXT',
                ),
              ),
            if (_pickError != null) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _pickError!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            if (previews != null && results == null) ...[
              const SizedBox(height: 20),
              Text(
                '${previews.length} arquivo(s) valido(s):',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...previews.map((p) => _PreviewTile(p: p)),
              const SizedBox(height: 16),
              if (previews.any((p) => p.participantExists))
                FilledButton.icon(
                  onPressed: _importing ? null : _importAll,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(
                    'Gravar ${previews.where((p) => p.participantExists).length} '
                    'resposta(s) no Firebase',
                  ),
                ),
            ],
            if (results != null) ...[
              const SizedBox(height: 16),
              Text(
                _done ? 'Importacao concluida!' : 'Gravando...',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...results.map((r) => _ResultTile(r: r)),
              if (_done) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir'),
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
  final _QuestionnaireImportPreview p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = p.participantExists;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        isThreeLine: true,
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: ok ? Colors.green : Colors.red,
        ),
        title: Text('${p.payload.participantId} — ${p.displayName}'),
        subtitle: Text(
          '${p.fileName}\n'
          'Periodo: ${p.payload.period}  ·  '
          'Arquitetura no periodo: ${p.architectureDuringPeriod}\n'
          'Atribuicao inicial: ${p.assignedArchitecture}'
          '${p.existingImportedAt != null ? '\nJa importado em ${p.existingImportedAt} (sera substituido)' : ''}',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.r});
  final _QuestionnaireImportResult r;

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

    final p = r.preview;
    return ListTile(
      dense: true,
      leading: icon,
      title: Text('${p.payload.participantId} — ${p.payload.period}'),
      subtitle: r.errorMessage != null
          ? Text(r.errorMessage!)
          : Text('Arquitetura: ${p.architectureDuringPeriod}'),
    );
  }
}
