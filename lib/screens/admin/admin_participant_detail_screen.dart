import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/experiment/admin_study_remote_service.dart';
import '../../domain/models/participant_study_config.dart';
import '../../domain/models/subjective_questionnaire_payload.dart';

class AdminParticipantDetailScreen extends StatefulWidget {
  const AdminParticipantDetailScreen({
    super.key,
    required this.participantId,
    required this.isAdminSlot,
  });

  final String participantId;
  final bool isAdminSlot;

  @override
  State<AdminParticipantDetailScreen> createState() =>
      _AdminParticipantDetailScreenState();
}

class _AdminParticipantDetailScreenState extends State<AdminParticipantDetailScreen> {
  final _service = AdminStudyRemoteService();

  bool _loading = true;
  Object? _error;
  String _architecture = ParticipantStudyConfig.kOnlineFirst;
  bool _appEnabled = true;
  bool _telemetryEnabled = true;
  bool _saving = false;
  bool _exporting = false;

  ParticipantStudyConfig? _cfg;
  String _originalArchitecture = ParticipantStudyConfig.kOnlineFirst;
  Map<String, SubjectiveQuestionnaireImportRecord?> _questionnaires = const {};

  @override
  void initState() {
    super.initState();
    assert(kDebugMode);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseDatabase.instance
          .ref('participants/${widget.participantId}')
          .get();
      if (!snap.exists || snap.value is! Map) {
        throw StateError('Participante nao encontrado.');
      }
      final map = (snap.value! as Map).map((k, v) => MapEntry(k.toString(), v));
      final cfg = ParticipantStudyConfig.fromMap(map);
      _architecture = cfg.architecture;
      _appEnabled = cfg.appEnabled;
      _telemetryEnabled = cfg.telemetryEnabled;
      _cfg = cfg;
      _originalArchitecture = cfg.architecture;
      _questionnaires =
          await _service.fetchSubjectiveQuestionnaireStatus(widget.participantId);
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_architecture != _originalArchitecture) {
        await _service.updateArchitecture(widget.participantId, _architecture);
      }
      await _service.updateFlags(
        participantId: widget.participantId,
        appEnabled: _appEnabled,
        telemetryEnabled: _telemetryEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alteracoes gravadas.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export(String arch) async {
    setState(() => _exporting = true);
    try {
      await _service.shareTelemetryExport(
        participantId: widget.participantId,
        architectureFilter: arch,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportacao: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _studyStartedLabel(ParticipantStudyConfig? c) {
    final s = c?.studyStartedAt;
    if (s == null) {
      return 'Ainda nao iniciou no telemovel (sem study_started_at). '
          'Gravado na primeira abertura com codigo valido.';
    }
    return s.toUtc().toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.participantId)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.participantId)),
        body: Center(child: Text('$_error')),
      );
    }

    final cfg = _cfg!;
    final daysOn = cfg.daysOnlinePhase ?? 0;
    final daysOff = cfg.daysOfflinePhase ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.participantId)),
      body: AbsorbPointer(
        absorbing: _saving || _exporting,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.isAdminSlot)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Conta de investigador (debug). Os participantes reais '
                    'devem usar codigos P001, P002, etc.',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_architecture),
              initialValue: _architecture,
              decoration: const InputDecoration(
                labelText: 'Arquitetura atual',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ParticipantStudyConfig.kOnlineFirst,
                  child: Text('online-first'),
                ),
                DropdownMenuItem(
                  value: ParticipantStudyConfig.kOfflineFirst,
                  child: Text('offline-first'),
                ),
              ],
              onChanged: (v) => setState(() => _architecture = v ?? _architecture),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('App ativo'),
              subtitle: const Text('Se desligado, o participante ve ecrã de estudo encerrado.'),
              value: _appEnabled,
              onChanged: (v) => setState(() => _appEnabled = v),
            ),
            SwitchListTile(
              title: const Text('Telemetria ativa'),
              subtitle: const Text('Se desligado, o app deixa de registar eventos.'),
              value: _telemetryEnabled,
              onChanged: (v) => setState(() => _telemetryEnabled = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tempo no experimento (somente leitura)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Contagem em dias civis UTC desde a primeira ligação ao app com '
              'codigo valido. Cada dia conta para online-first ou offline-first '
              'consoante a arquitetura vigente nesse dia (meio-dia UTC), '
              'incluindo mudanças feitas aqui.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Início do experimento (study_started_at)'),
              subtitle: Text(_studyStartedLabel(cfg)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dias acumulados em online-first'),
              subtitle: Text('$daysOn'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dias acumulados em offline-first'),
              subtitle: Text('$daysOff'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Questionarios subjetivos (T1 / T2)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...['T1', 'T2'].map((period) {
              final q = _questionnaires[period];
              final archLabel = q?.architectureDuringPeriod ??
                  SubjectiveQuestionnairePayload.architectureDuringPeriod(
                    assignedArchitecture: cfg.architecture,
                    period: period,
                  );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Periodo $period'),
                subtitle: Text(
                  q == null
                      ? 'Nao importado  ·  arquitetura esperada: $archLabel'
                      : 'Importado em ${q.importedAt}\n'
                          'Arquitetura no periodo: ${q.architectureDuringPeriod}',
                ),
                isThreeLine: q != null,
                trailing: Icon(
                  q == null ? Icons.radio_button_unchecked : Icons.check_circle,
                  color: q == null ? Colors.grey : Colors.green,
                  size: 20,
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gravar alteracoes'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Exportar telemetria (Realtime Database)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Filtra eventos pelo campo `architecture` gravado em cada evento.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _exporting
                  ? null
                  : () => _export(ParticipantStudyConfig.kOnlineFirst),
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Exportar telemetria online-first'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _exporting
                  ? null
                  : () => _export(ParticipantStudyConfig.kOfflineFirst),
              icon: const Icon(Icons.storage_outlined),
              label: const Text('Exportar telemetria offline-first'),
            ),
          ],
        ),
      ),
    );
  }
}
