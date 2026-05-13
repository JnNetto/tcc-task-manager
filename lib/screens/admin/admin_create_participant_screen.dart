import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/experiment/admin_study_remote_service.dart';
import '../../domain/models/participant_study_config.dart';

class AdminCreateParticipantScreen extends StatefulWidget {
  const AdminCreateParticipantScreen({super.key});

  @override
  State<AdminCreateParticipantScreen> createState() =>
      _AdminCreateParticipantScreenState();
}

class _AdminCreateParticipantScreenState extends State<AdminCreateParticipantScreen> {
  final _digitsCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _service = AdminStudyRemoteService();
  String _architecture = ParticipantStudyConfig.kOnlineFirst;
  bool _saving = false;

  @override
  void dispose() {
    _digitsCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    assert(kDebugMode);
    final digits = _digitsCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createParticipant(
        digits: digits,
        displayName: name,
        architecture: _architecture,
      );
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo participante')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Codigo: tres digitos (001 a 999). Sera criado o no '
              '`participants/P###` no Realtime Database com perfil minimo '
              'para o participante conseguir entrar na app release.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _digitsCtrl,
              decoration: const InputDecoration(
                labelText: 'Codigo (3 digitos)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome ou pseudonimo',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_architecture),
              initialValue: _architecture,
              decoration: const InputDecoration(
                labelText: 'Arquitetura inicial',
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
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar no Firebase'),
            ),
          ],
        ),
      ),
    );
  }
}
