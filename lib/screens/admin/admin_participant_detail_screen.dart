import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/experiment/admin_study_remote_service.dart';
import '../../domain/models/participant_study_config.dart';

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
  final _daysOnlineCtrl = TextEditingController();
  final _daysOfflineCtrl = TextEditingController();

  bool _loading = true;
  Object? _error;
  String _architecture = ParticipantStudyConfig.kOnlineFirst;
  bool _appEnabled = true;
  bool _telemetryEnabled = true;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode);
    _load();
  }

  @override
  void dispose() {
    _daysOnlineCtrl.dispose();
    _daysOfflineCtrl.dispose();
    super.dispose();
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
      _daysOnlineCtrl.text = '${cfg.daysOnlinePhase ?? 0}';
      _daysOfflineCtrl.text = '${cfg.daysOfflinePhase ?? 0}';
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateArchitecture(widget.participantId, _architecture);
      await _service.updateFlags(
        participantId: widget.participantId,
        appEnabled: _appEnabled,
        telemetryEnabled: _telemetryEnabled,
      );
      final dOn = int.tryParse(_daysOnlineCtrl.text.trim()) ?? 0;
      final dOff = int.tryParse(_daysOfflineCtrl.text.trim()) ?? 0;
      await _service.updateDayCounters(
        participantId: widget.participantId,
        daysOnline: dOn.clamp(0, 9999),
        daysOffline: dOff.clamp(0, 9999),
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
            const SizedBox(height: 8),
            TextField(
              controller: _daysOnlineCtrl,
              decoration: const InputDecoration(
                labelText: 'Dias em online-first (referencia)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysOfflineCtrl,
              decoration: const InputDecoration(
                labelText: 'Dias em offline-first (referencia)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
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
