import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/participant_impression_service.dart';
import '../providers/study_session_controller.dart';
import '../services/network_simulator.dart';

/// Folha modal para o participante relatar impressões imediatas sobre o app.
Future<bool?> showParticipantImpressionSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _ParticipantImpressionSheet(),
  );
}

class _ParticipantImpressionSheet extends StatefulWidget {
  const _ParticipantImpressionSheet();

  @override
  State<_ParticipantImpressionSheet> createState() =>
      _ParticipantImpressionSheetState();
}

class _ParticipantImpressionSheetState extends State<_ParticipantImpressionSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _submitting) return;

    final session = context.read<StudySessionController>();
    setState(() => _submitting = true);

    try {
      await ParticipantImpressionService(participantId: session.participantId)
          .submitImpression(
            text: text,
            architecture: session.prototype,
            studyDay: session.dayOfStudy,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OfflineException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem ligacao agora. Tente enviar o comentario mais tarde.',
          ),
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Comentario sobre o app',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Relate a sua impressao imediata quando quiser. '
            'O texto fica guardado no seu registo de participante.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ex.: achei facil criar uma tarefa, ou senti lentidao…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _controller.text.trim().isEmpty || _submitting
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
