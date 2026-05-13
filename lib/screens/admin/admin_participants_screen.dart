import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/debug_admin.dart';
import '../../data/experiment/admin_study_remote_service.dart';
import 'admin_create_participant_screen.dart';
import 'admin_participant_detail_screen.dart';

/// Painel do investigador (apenas em build debug).
class AdminParticipantsScreen extends StatefulWidget {
  const AdminParticipantsScreen({super.key});

  @override
  State<AdminParticipantsScreen> createState() => _AdminParticipantsScreenState();
}

class _AdminParticipantsScreenState extends State<AdminParticipantsScreen> {
  final _service = AdminStudyRemoteService();
  Future<List<AdminParticipantRow>>? _future;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode);
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listParticipants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participantes (investigador)'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AdminCreateParticipantScreen()),
          );
          if (created == true && mounted) _reload();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Novo participante'),
      ),
      body: FutureBuilder<List<AdminParticipantRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: ${snap.error}'),
              ),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Nenhum participante no RTDB.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = list[i];
              final isAdmin = p.id == kDebugAdminParticipantId;
              return ListTile(
                title: Text(p.displayName),
                subtitle: Text(
                  '${p.id}  ·  ${p.architecture}\n'
                  'Dias online-first: ${p.daysOnlinePhase}  ·  '
                  'Dias offline-first: ${p.daysOfflinePhase}',
                ),
                isThreeLine: true,
                trailing: p.appEnabled
                    ? (p.telemetryEnabled
                        ? const Icon(Icons.circle, color: Colors.green, size: 12)
                        : const Icon(Icons.circle, color: Colors.orange, size: 12))
                    : const Icon(Icons.circle, color: Colors.red, size: 12),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AdminParticipantDetailScreen(
                        participantId: p.id,
                        isAdminSlot: isAdmin,
                      ),
                    ),
                  );
                  if (changed == true && mounted) _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}
