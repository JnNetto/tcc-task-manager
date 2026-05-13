import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/study_session_controller.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final exp = context.watch<StudySessionController>();
    const totalDays = AppConfig.periodDurationDays;
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracoes')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('ID do participante'),
            subtitle: Text(exp.participantId),
          ),
          ListTile(
            title: const Text('Dia do estudo'),
            subtitle: Text('${exp.dayOfStudy} de $totalDays'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            title: const Text('Exportar dados'),
            subtitle: const Text('Gerar JSON e abrir compartilhamento'),
            enabled: !_exporting,
            onTap: _exporting
                ? null
                : () async {
                    setState(() => _exporting = true);
                    try {
                      final path = await ExportService.exportAndShare(
                        exp.participantId,
                        exp.prototype,
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Arquivo exportado: $path')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Falha na exportacao: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _exporting = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
