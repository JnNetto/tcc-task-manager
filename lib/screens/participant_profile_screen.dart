import 'package:flutter/material.dart';

import '../domain/models/profile_questionnaire.dart';
import '../legal/research_consent.dart';
import '../utils/participant_name_match.dart';

/// Questionário básico após o código (nome, idade, género, escolaridade).
class ParticipantProfileScreen extends StatefulWidget {
  const ParticipantProfileScreen({
    super.key,
    required this.onSubmit,
    this.registeredName,
  });

  final Future<void> Function(ProfileQuestionnaire answers) onSubmit;

  /// Nome cadastrado com o codigo no RTDB; deve coincidir com o campo do formulario.
  final String? registeredName;

  @override
  State<ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender;
  String? _education;
  bool _consentAccepted = false;
  bool _submitting = false;

  static const _genderOptions = [
    ('female', 'Feminino'),
    ('male', 'Masculino'),
    ('non_binary', 'Não-binário'),
    ('prefer_not', 'Prefiro não informar'),
    ('other', 'Outro'),
  ];

  static const _educationLevels = [
    ('fund_inc', 'Fundamental incompleto'),
    ('fund_comp', 'Fundamental completo'),
    ('med_inc', 'Médio incompleto'),
    ('med_comp', 'Médio completo'),
    ('sup_inc', 'Superior incompleto'),
    ('sup_comp', 'Superior completo'),
    ('pos', 'Pós-graduação'),
    ('edu_skip', 'Prefiro não informar'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _openConsentTerms() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(ResearchConsent.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              ResearchConsent.fullText,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _education == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione género e escolaridade.')),
      );
      return;
    }
    if (!_consentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Leia o termo de consentimento e marque a opção de concordância para continuar.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final age = int.parse(_ageCtrl.text.trim());
      final acceptedAt = DateTime.now().toUtc().toIso8601String();
      await widget.onSubmit(
        ProfileQuestionnaire(
          name: _nameCtrl.text.trim(),
          age: age,
          gender: _gender!,
          education: _education!,
          consentVersion: ResearchConsent.version,
          consentAcceptedAtIso: acceptedAt,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre si')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Responda ao questionário para continuar. Os dados são usados apenas no âmbito do estudo.',
                style: TextStyle(fontSize: 15),
              ),
              if (widget.registeredName != null &&
                  widget.registeredName!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Use o mesmo nome ou pseudónimo que lhe foi atribuido no estudo '
                  '(cadastro deste codigo).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome ou pseudónimo',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obrigatório';
                  final expected = widget.registeredName?.trim();
                  if (expected != null &&
                      expected.isNotEmpty &&
                      !participantNamesMatch(v, expected)) {
                    return 'O nome nao coincide com o cadastro deste codigo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Idade',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obrigatório';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 10 || n > 120) return 'Idade inválida';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('gender_${_gender ?? 'none'}'),
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Género',
                  border: OutlineInputBorder(),
                ),
                items: _genderOptions
                    .map(
                      (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('edu_${_education ?? 'none'}'),
                initialValue: _education,
                decoration: const InputDecoration(
                  labelText: 'Escolaridade',
                  border: OutlineInputBorder(),
                ),
                items: _educationLevels
                    .map(
                      (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _education = v),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Checkbox(
                      value: _consentAccepted,
                      onChanged: _submitting
                          ? null
                          : (v) =>
                              setState(() => _consentAccepted = v ?? false),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Li e concordo, de forma livre e informada, com o '
                          'termo de consentimento e com o tratamento dos meus '
                          'dados pessoais para as finalidades do estudo aí '
                          'descritas (incluindo telemetria técnica e dados das '
                          'tarefas, conforme aplicável).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: _submitting ? null : _openConsentTerms,
                            child: const Text('Ler termos completos'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
